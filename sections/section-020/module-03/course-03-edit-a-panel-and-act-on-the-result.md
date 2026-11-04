# Edit A Panel And Act On The Result

The dashboard `Outpost Logs` has two panels, and both query the wrong namespace. During an incident the fast fix is to edit the query in place and save it. You also need to know how long that edit lasts, and then use what the panel shows to stop the Pods that fail.

<!-- astrona:playground:renew -->

## Edit and save a panel

Open **Dashboards**, then **Outpost Logs**. Open the menu of the panel `Error lines` and select **Edit**. Replace the query with:

```text
{namespace="outpost"} |= "ERROR"
```

Go back to the dashboard. Edit the panel `Streams with errors` the same way, with this query:

```text
count(rate({namespace="outpost"} |= "ERROR" [5m]))
```

Select **Save dashboard** and confirm. The save goes into Grafana's database. Read it back from the API:

```sh
curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/outpost-logs |
  jq '{provisioned: .meta.provisioned, queries: [.dashboard | .. | objects | select(has("expr")) | .expr]}'
```

Look for both new queries, and for `provisioned` set to `false`.

A script can make the same edit: read the dashboard from `/api/dashboards/uid/outpost-logs`, change the query in the JSON and post it to `/api/dashboards/db` with this shape:

```json
{
  "dashboard": {},
  "overwrite": false,
  "message": "Show errors from outpost"
}
```

Put the whole dashboard you read in `dashboard`. With `overwrite` set to `false`, Grafana refuses the save if someone else changed the dashboard after you read it.

## How long a saved edit lasts

The rule for a dashboard that must last is **dashboards as code**: keep its JSON in version control and provision it from a file or a labelled ConfigMap, so that Grafana restores it when it starts with an empty database. A save in the web interface does none of this. It changes only the database, it has no review and no history in your repository, and it disappears with the database. In this environment the database is on an `emptyDir` volume, which is deleted with the Pod.

Keep a copy of the edited dashboard, then prove the loss by replacing the Pod:

```sh
curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/outpost-logs |
  jq '{dashboard: (.dashboard | .id = null), overwrite: true, message: "Restore"}' > outpost-logs-saved.json
kubectl -n monitoring rollout restart deployment/kps-grafana
kubectl -n monitoring rollout status deployment/kps-grafana
```

The restart ends your Grafana port-forward, so start it again in its terminal. Then ask for the dashboard and the data source:

```sh
curl -sS -o /dev/null -w '%{http_code}\n' -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/outpost-logs
curl -sS -o /dev/null -w '%{http_code}\n' -u admin:starfleet http://127.0.0.1:3300/api/datasources/uid/loki
```

Look for `404` twice. Both were only in the database. Restore them from the files you saved:

```sh
curl -fsS -u admin:starfleet -H 'Content-Type: application/json' \
  -X POST http://127.0.0.1:3300/api/datasources/ -d @loki-data-source.json >/dev/null
curl -fsS -u admin:starfleet -H 'Content-Type: application/json' \
  -X POST http://127.0.0.1:3300/api/dashboards/db -d @outpost-logs-saved.json | jq
```

Use an edit in the web interface to fix or explore something now. When the change is worth keeping, export the JSON and put it into the file that provisions the dashboard.

## Find the Pods and stop them

Ask Loki which Pods write error lines:

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query \
  --data-urlencode 'query=sum by (pod) (count_over_time({namespace="outpost"} |= "ERROR" [5m]))' |
  jq -r '.data.result[] | "\(.metric.pod) \(.value[1])"'
```

Look for `probe` Pods, whose names have generated endings, and the Pod `depot-0`. A Pod does not scale, so find what owns each one:

```sh
kubectl -n outpost get pods \
  -o custom-columns='POD:.metadata.name,KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name'
kubectl -n outpost get replicasets \
  -o custom-columns='REPLICASET:.metadata.name,KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name'
```

Look for two kinds of owner. `depot-0` belongs directly to the StatefulSet `depot`. A `probe` Pod belongs to a ReplicaSet, and that ReplicaSet belongs to the Deployment `probe`. Scale the two controllers to `0`:

```sh
kubectl -n outpost scale deployment probe --replicas=0
kubectl -n outpost scale statefulset depot --replicas=0
```

Then check the result:

```sh
kubectl -n outpost get deployments,statefulsets
```

Look for `probe` and `depot` with `0` Pods, while `beacon` and `scout` still run. Run the Loki query again after five minutes and look for an empty result. You went from a log query to a change on the exact controllers that needed it.

## Common pitfalls

> [!WARNING]
> **Saving over a provisioned dashboard.** Grafana refuses to save a dashboard that comes from a provisioning file. Change the file, or save a copy for your own experiments.

> [!WARNING]
> **Trusting a web edit to last.** A saved edit is gone when the database is lost. Put a change you want to keep into the provisioned file.

> [!WARNING]
> **Deleting the Pod.** The controller replaces a deleted Pod at once, and the errors continue. Change the replica count of its controller.

> [!WARNING]
> **Stopping on a mention.** A query that ignores letter case also finds healthy Pods that only mention the word. Check the line text before you scale anything to `0`.

## Your mission: Query Loki And Stop The Failing Workloads Lab

You can now tune a Loki data source, correct and save a panel query and turn a query result into action. The lab asks you to change Maximum lines, correct two panels and scale down exactly the controllers whose Pods write error lines.

```sh
astrona stop ats-020-playground-020-03
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-03/labs/lab-01
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-03/labs/lab-01
astrona destroy ats-020-lab-020-03
astrona start ats-020-playground-020-03
```

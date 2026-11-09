# Repair And Save A Loki Dashboard

The dashboard `Outpost Logs` has two panels, and both query the wrong namespace. During an incident the fast fix is to edit the query in place and save it. You also need to know how long that edit lasts, and verify that both panels query the intended namespace.

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


## Common pitfalls

> [!WARNING]
> - A UI save changes the database, not the provisioning source.
> - Use the actual Loki data-source UID in both panels.
> - Check the namespace and case-sensitive error filter before saving.

## Your mission: Repair A Loki Error Dashboard

Loki stores logs with `namespace`, `pod` and `container` labels. Grafana has the editable `loki` data source and the saved `outpost-logs` dashboard.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-020-03
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-30/labs/lab-01
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-020/module-30/labs/lab-01
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-020-03
astrona start ats-020-playground-020-03
```

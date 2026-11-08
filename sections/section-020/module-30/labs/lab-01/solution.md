# Solution

| Check | Step |
| --- | --- |
| `data-source` | Step 1 |
| `panels` | Step 2 |
| `scaled` | Steps 3 and 4 |

## The feedback loop

Open a separate terminal and start the grader in watch mode. It re-grades every few seconds, does not record an attempt and does not delete the lab:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-30/labs/lab-01
```

Leave it running and read which checks turn green after each step. Keep the plain `astrona submit` for the very end, because a plain submit is final and removes the lab.

Forward both Services in separate terminals and leave them running:

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3300:80
```

```sh
kubectl -n logging port-forward svc/loki 3100:3100
```

## Step 1: Change Maximum lines

To use the web interface, open `http://127.0.0.1:3300`, sign in as `admin` with the password `starfleet`, open **Connections**, then **Data sources**, then **Loki**. Type `250` in **Maximum lines** and select **Save & test**.

To use the API, read the whole data source, change one field and send the whole object back. A `PUT` replaces the settings, so sending only the one field would lose the others:

```sh
curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/datasources/uid/loki |
  jq '.jsonData.maxLines = 250' |
  curl -fsS -u admin:starfleet -H 'Content-Type: application/json' \
    -X PUT http://127.0.0.1:3300/api/datasources/uid/loki -d @-
```

Check the stored value:

```sh
curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/datasources/uid/loki | jq '.jsonData.maxLines'
```

Look for `250`, or `"250"` if you saved it in the web interface. Both pass. The `data-source` check turns green.

## Step 2: Correct the panels

To use the web interface, open **Dashboards**, then **Outpost Logs**. Open the menu of the panel `Error lines` and select **Edit**. Replace the query with:

```text
{namespace="outpost"} |= "ERROR"
```

Go back to the dashboard. Edit the panel `Streams with errors` the same way, with this query:

```text
count(rate({namespace="outpost"} |= "ERROR" [5m]))
```

Select **Save dashboard** and confirm.

To use the API, read the dashboard, change the two queries and post it back:

```sh
curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/outpost-logs |
  jq '{
    dashboard: (.dashboard
      | (.panels[] | select(.title == "Error lines") | .targets[0].expr) = "{namespace=\"outpost\"} |= \"ERROR\""
      | (.panels[] | select(.title == "Streams with errors") | .targets[0].expr) = "count(rate({namespace=\"outpost\"} |= \"ERROR\" [5m]))"),
    overwrite: false,
    message: "Show outpost errors"
  }' |
  curl -fsS -u admin:starfleet -H 'Content-Type: application/json' \
    -X POST http://127.0.0.1:3300/api/dashboards/db -d @-
```

Read the saved queries back:

```sh
curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/outpost-logs |
  jq '.dashboard.panels[] | {title, expr: .targets[0].expr}'
```

Look for the two new queries. The `panels` check turns green. Its data comes from Loki, so wait until the panels show data if it stays red at first.

## Step 3: Find the Pods

Ask Loki for the number of error lines per Pod over the last hour:

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query \
  --data-urlencode 'query=sum by (pod) (count_over_time({namespace="outpost"} |= "ERROR" [1h]))' |
  jq -r '.data.result[] | "\(.metric.pod) \(.value[1])"'
```

Look for one line per Pod that writes errors. The filter is case-sensitive, so a Pod that only writes lower-case `error` does not appear. Wait a moment and run it again if you expect more Pods, because `probe` only logs errors for the failing requests it receives.

Find the controller of each Pod from its owner. Replace `POD` with a name from the previous command:

```sh
kubectl -n outpost get pod POD -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{"\n"}'
```

A Deployment's Pod shows a ReplicaSet, and the ReplicaSet name is the Deployment name plus a hash. A StatefulSet's Pod shows the StatefulSet itself. In this lab the commands below use the result: the Deployment `probe` and the StatefulSet `cargo`.

## Step 4: Scale the controllers to 0

```sh
kubectl -n outpost scale deployment/probe --replicas=0
kubectl -n outpost scale statefulset/cargo --replicas=0
```

Check what still runs:

```sh
kubectl -n outpost get deployments,statefulsets,pods
```

Look for `probe` and `cargo` at `0` with no Pods left, and `beacon` and `scout` still ready. `beacon` writes `retrying after error` in lower case, so it is not an error line, and `relay` writes errors but is in `starfleet`, outside the task. The `scaled` check turns green. Loki keeps the earlier lines, which is how the grader still knows which controllers wrote them.

## Submit

When all three checks are green in watch mode, stop it with `Ctrl+C` and submit once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-30/labs/lab-01
```

## If a check stays red

- `data-source`: read `jsonData.maxLines` from the API. The health check runs from inside Grafana, so `http://localhost:3100` fails even when your port-forward works.
- `panels`: a panel with a typing error in its query is refused by Loki. Paste the query into **Explore** and read the error there.
- `scaled`: it counts every error line of the last six hours. Run the query in step 3 with `[6h]` and check each Pod again.

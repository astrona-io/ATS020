# Solution

| Check | Step |
| --- | --- |
| `data-source` | Step 1 |
| `panels` | Step 2 |
| `cause` | Steps 3 and 4 |
| `fixed` | Step 5 |

## The feedback loop

Open a separate terminal and start the grader in watch mode. It re-grades every few seconds, does not record an attempt and does not delete the lab:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/capstone/labs/lab-02
```

Keep the plain `astrona submit` for the very end, because a plain submit is final and removes the lab.

Forward all three Services in separate terminals and leave them running:

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3300:80
```

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

```sh
kubectl -n logging port-forward svc/loki 3100:3100
```

## Step 1: Connect Loki

Create the data source through the API, because the web interface generates its own UID and the panel expects `loki`:

```sh
jq -n '{name: "Loki", uid: "loki", type: "loki", access: "proxy", url: "http://loki.logging:3100", jsonData: {maxLines: 500}}' |
  curl -fsS -u admin:starfleet -H 'Content-Type: application/json' \
    -X POST http://127.0.0.1:3300/api/datasources/ -d @-
```

To set the value in the web interface instead, leave out `jsonData` from the call above, open `http://127.0.0.1:3300`, sign in as `admin` with the password `starfleet`, and open **Connections**, then **Data sources**, then **Loki**. Type `500` in **Maximum lines** and select **Save & test**.

Ask Grafana to test the connection:

```sh
curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/datasources/uid/loki/health | jq
```

Look for a status of `OK`. The `data-source` check turns green.

## Step 2: Correct the dashboard

To use the web interface, open **Dashboards**, then **Incident Overview**, edit each panel and replace its query. Then select **Save dashboard**.

| Panel | Query |
| --- | --- |
| `Failed requests` | `sum by (service) (rate(fleet_requests_total{namespace="outpost",status="500"}[5m]))` |
| `Error lines` | `{namespace="outpost"} \|= "ERROR"` |

The backslash in the table only protects the pipe character. Type `|=` in Grafana.

To use the API:

```sh
curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/incident-overview |
  jq '{
    dashboard: (.dashboard
      | (.panels[] | select(.title == "Failed requests") | .targets[0].expr) = "sum by (service) (rate(fleet_requests_total{namespace=\"outpost\",status=\"500\"}[5m]))"
      | (.panels[] | select(.title == "Error lines") | .targets[0].expr) = "{namespace=\"outpost\"} |= \"ERROR\""),
    overwrite: false,
    message: "Show the incident"
  }' |
  curl -fsS -u admin:starfleet -H 'Content-Type: application/json' \
    -X POST http://127.0.0.1:3300/api/dashboards/db -d @-
```

The `panels` check turns green.

## Step 3: Record the service

Ask Prometheus which service fails:

```sh
curl -fsSG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=sum by (service) (rate(fleet_requests_total{namespace="outpost",status="500"}[5m])) > 0' |
  jq -r '.data.result[].metric.service'
```

Look for one service name. The Deployment has the same name as the Service. The commands below use that result, which is `cargo` in this lab:

```sh
echo cargo > /tmp/ats-020-incident-service.txt
```

## Step 4: Record the cause

Read the error lines:

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="outpost"} |= "ERROR"' \
  --data-urlencode 'since=1h' --data-urlencode 'limit=5' |
  jq -r '.data.result[] | .stream.pod as $pod | .values[] | "\($pod) \(.[1])"'
```

Look for lines from one Pod with the message `cannot open store` and a `path=` value. The lines from `probe` that say `client retried after error` do not appear, because the filter is case-sensitive. Save the value:

```sh
echo /data/missing > /tmp/ats-020-incident-path.txt
```

The `cause` check turns green.

## Step 5: Fix the service

Compare the value and the mounted volumes with a healthy service:

```sh
kubectl -n outpost set env deployment/cargo --list
kubectl -n outpost set env deployment/scout --list
kubectl -n outpost get deployment cargo -o jsonpath='{.spec.template.spec.containers[0].volumeMounts}{"\n"}'
```

Look at `STORE_PATH`: the healthy service uses a directory that is mounted, and the failing service does not. Set the correct value and wait for the new Pod:

```sh
kubectl -n outpost set env deployment/cargo STORE_PATH=/data/store
kubectl -n outpost rollout status deployment/cargo
```

Wait about a minute, then look for an empty result from both of these:

```sh
curl -fsSG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(fleet_requests_total{namespace="outpost",status="500"}[1m])) > 0' | jq '.data.result'
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query \
  --data-urlencode 'query=sum(count_over_time({namespace="outpost"} |= "ERROR" [1m]))' | jq '.data.result'
```

The `fixed` check turns green.

## Submit

When all four checks are green in watch mode, stop it with `Ctrl+C` and submit once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/capstone/labs/lab-02
```

## If a check stays red

- `data-source`: a data source made in the web interface has a generated UID. Delete it and create it through the API. The health check runs from inside Grafana, so `http://localhost:3100` fails.
- `panels`: both queries run over the recent past, so the panels stay correct after the fix. Check that the panel for failures selects `status="500"` and groups by `service`.
- `cause`: compare each file with the query results. Write only the value, with no label.
- `fixed`: the checks use a one-minute window, so wait and let watch mode check again.

# Panels For Rate, Error Ratio And Latency

Three questions come first in almost every incident: how many requests arrive, how many of them fail, and how long they take. A Grafana panel draws the result of a query against a data source, the connection to a backend such as Prometheus. Each question needs a query and a display suited to its number. This part writes a dashboard for `scout` as a JSON file inside a ConfigMap, with one panel per question, and checks that every panel's query returns data through Grafana.

## Three questions, three visualisations

Prometheus Query Language (PromQL) selects and calculates over metrics, numbers an application reports about itself. A counter only increases until a process restarts; `rate()` calculates its average increase per second over a time range. A histogram counts observations in size buckets, and `histogram_quantile()` estimates the value below which a chosen fraction falls.

The query decides what the number means; the visualisation decides how fast a person can read it. The rule of thumb is simple:

| Question | PromQL shape | Visualisation | Unit |
| --- | --- | --- | --- |
| How many requests per second? | `sum by (status) (rate(...[1m]))` | Time series, one line per status | `reqps` (requests per second) |
| What share of requests fail? | failed rate divided by total rate | Stat, one number with a colour threshold | `percentunit` (0.05 shows as 5%) |
| How long do requests take? | `histogram_quantile()` over the buckets | Time series, one line per quantile | `s` (seconds) |

A rate changes over time, so a graph shows its shape. A ratio is read as "good or bad now", so one big number that turns red above a threshold is faster to read. A latency needs more than one line, because the median (p50, the 50th percentile) and the 99th percentile (p99) tell different stories.

The **unit** matters as much as the query. `percentunit` expects a fraction between 0 and 1, which is what an error ratio is. If you choose `percent` instead, Grafana shows `0.13` as `0.13%` instead of `13%`.

## Write the dashboard

A dashboard in a file is the same JavaScript Object Notation (JSON) document Grafana stores internally. You only need a few fields: `uid`, `title`, `time`, `refresh` and `panels`. Each panel has an `id`, a `type`, a `title`, a `gridPos` (its position on a grid 24 columns wide), a `datasource` identified by its unique identifier (UID), a `fieldConfig` with the unit, and `targets`, the list of queries.

<!-- astrona:playground:renew -->

Save this as `configmap-dashboard-starfleet-requests.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-starfleet-requests
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  starfleet-requests.json: |
    {
      "uid": "starfleet-requests",
      "title": "Starfleet Requests",
      "schemaVersion": 41,
      "time": {"from": "now-15m", "to": "now"},
      "refresh": "30s",
      "panels": [
        {
          "id": 1,
          "type": "timeseries",
          "title": "Request rate",
          "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
          "datasource": {"type": "prometheus", "uid": "prometheus"},
          "fieldConfig": {"defaults": {"unit": "reqps"}, "overrides": []},
          "targets": [
            {
              "refId": "A",
              "expr": "sum by (status) (rate(http_requests_total{namespace=\"starfleet\"}[1m]))",
              "legendFormat": "{{status}}"
            }
          ]
        },
        {
          "id": 2,
          "type": "stat",
          "title": "Error ratio",
          "gridPos": {"x": 12, "y": 0, "w": 6, "h": 8},
          "datasource": {"type": "prometheus", "uid": "prometheus"},
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"color": "green", "value": null},
                  {"color": "red", "value": 0.05}
                ]
              }
            },
            "overrides": []
          },
          "targets": [
            {
              "refId": "A",
              "expr": "sum(rate(http_requests_total{namespace=\"starfleet\", status=~\"5..\"}[1m])) / sum(rate(http_requests_total{namespace=\"starfleet\"}[1m]))"
            }
          ]
        },
        {
          "id": 3,
          "type": "timeseries",
          "title": "Latency",
          "gridPos": {"x": 18, "y": 0, "w": 6, "h": 8},
          "datasource": {"type": "prometheus", "uid": "prometheus"},
          "fieldConfig": {"defaults": {"unit": "s"}, "overrides": []},
          "targets": [
            {
              "refId": "A",
              "expr": "histogram_quantile(0.5, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"starfleet\"}[5m])))",
              "legendFormat": "p50"
            },
            {
              "refId": "B",
              "expr": "histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"starfleet\"}[5m])))",
              "legendFormat": "p99"
            }
          ]
        }
      ]
    }
```

A few details in this file:

- Every panel points at the data source by `"uid": "prometheus"`, the fixed UID from the data source file. A dashboard copied to another cluster works as long as that UID exists there.
- Inside JSON, the double quotes of a PromQL label value must be escaped as `\"`. A missing backslash makes the whole document invalid, and Grafana cannot parse the copied file.
- `legendFormat` names each line. `{{status}}` takes the value of the `status` label, so the graph shows one line called `200` and one called `500`.
- The latency queries keep `le`, the bucket's upper-bound label, in `sum by (le)`. `histogram_quantile()` needs that label to calculate the estimate.
- The stat panel's `thresholds` turn the number red at `0.05`, that is 5%. The first step, with `value: null`, is the colour below the first threshold.
- `refId` is the letter that names each query in a panel. The latency panel has two queries, `A` and `B`.

Apply it:

```sh
kubectl apply -f configmap-dashboard-starfleet-requests.yaml
```

## Check the dashboard and its queries

Then check the result. The dashboard sidecar writes the file and asks Grafana to reload, as the data source sidecar did. Search for dashboards through the application programming interface (API):

```sh
curl -s -u admin:starfleet "http://127.0.0.1:3300/api/search?type=dash-db" | jq '.[] | {uid, title}'
```

You should see:

```text
{
  "uid": "starfleet-requests",
  "title": "Starfleet Requests"
}
```

Open `http://127.0.0.1:3300/d/starfleet-requests` in a browser to see the three panels. On the command line, list each panel's queries as Grafana stored them:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/starfleet-requests |
  jq -r '.dashboard.panels[] | .title as $title | .targets[] | "\($title) [\(.refId)]: \(.expr)"'
```

You should see:

```text
Request rate [A]: sum by (status) (rate(http_requests_total{namespace="starfleet"}[1m]))
Error ratio [A]: sum(rate(http_requests_total{namespace="starfleet", status=~"5.."}[1m])) / sum(rate(http_requests_total{namespace="starfleet"}[1m]))
Latency [A]: histogram_quantile(0.5, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m])))
Latency [B]: histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m])))
```

A panel that loads but shows "No data" usually has a query problem, not a Grafana problem. To check the current value of a panel query, send an instant query to Grafana's query API, which passes it to the data source. The time series panels request values across a time range instead. This helper sends one PromQL expression to the `prometheus` data source and prints each result's labels and value:

```sh
grafana_query() {
  curl -s -u admin:starfleet -H 'Content-Type: application/json' http://127.0.0.1:3300/api/ds/query \
    -d "$(jq -n --arg expr "$1" '{from: "now-5m", to: "now", queries: [{refId: "A", datasource: {uid: "prometheus"}, expr: $expr, instant: true}]}')" |
    jq -r '.results.A.frames[] | "\(.schema.fields[1].labels // {} | to_entries | map("\(.key)=\(.value)") | join(","))\t\(.data.values[1][0])"'
}
```

Run the queries of the three panels:

```sh
grafana_query 'sum by (status) (rate(http_requests_total{namespace="starfleet"}[1m]))'
grafana_query 'sum(rate(http_requests_total{namespace="starfleet", status=~"5.."}[1m])) / sum(rate(http_requests_total{namespace="starfleet"}[1m]))'
grafana_query 'histogram_quantile(0.5, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m])))'
grafana_query 'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m])))'
```

You should see something like this; your numbers will differ a little:

```text
status=200	0.9969666666666668
status=500	0.11134277777777779
	0.10046965526051463
	0.00268425919203932
	2.281481368769865
```

Read it panel by panel. `scout` in `starfleet` serves about 1.00 successful and 0.11 failed requests per second, so the error ratio is about 0.10. With the unit `percentunit`, the stat panel shows it as about 10%, in red because it is above the `0.05` threshold. The median request takes about 2.7 milliseconds, but the p99 is about 2.3 seconds, because the `/delay/1` requests sit in the histogram bucket between 1 and 2.5 seconds and `histogram_quantile()` estimates inside that bucket. The ratio and the quantiles have no labels, so the label column is empty.

A percentile estimates a boundary, rather than the longest individual request. Choose the percentile that matches your service-level question, and remember that histogram bucket widths limit precision. A p99 above a second means that estimated boundary exceeds a second; it does not report the maximum.

You can now write a dashboard as JSON, give each panel the visualisation and unit that fits its number, and check every query through Grafana. Every query still names `starfleet`, though. The open question is how to show `outpost` without copying the whole dashboard.

## Common pitfalls

> [!WARNING]
> - **Unescaped quotes inside the JSON.** `namespace="starfleet"` must be written `namespace=\"starfleet\"` inside a JSON string. Check the document with `jq` before you apply it.
> - **The wrong unit.** An error ratio is a fraction; use `percentunit`. With `percent`, `0.13` shows as `0.13%`.
> - **Reading a raw counter as request rate.** A counter shows the total since process start. Use `rate()` when the question is requests per second.
> - **Treating a percentile as the maximum.** A percentile is an estimate from buckets. It does not tell you the longest individual request.

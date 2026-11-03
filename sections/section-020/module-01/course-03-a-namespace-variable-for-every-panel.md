# A Namespace Variable For Every Panel

A Grafana dashboard is a page of panels that query a data source, a connection to a backend such as Prometheus. The dashboard works for `starfleet`, but `scout` also runs in `outpost`. Copying the dashboard for every namespace doubles the files and the chance that one copy is fixed while the other is not.

A **dashboard variable** solves this: one dashboard, a drop-down list at the top, and every panel's query follows the value the viewer picks. This part adds a `namespace` variable and points all four queries at it.

## How a variable works

A namespace groups Kubernetes resources. The dashboard definition uses JavaScript Object Notation (JSON), a format that stores objects, lists and values as text.

A variable is defined in the dashboard's `templating.list`. A variable of type `query` fills its drop-down list by running a query against a data source.

Prometheus Query Language (PromQL) is the language that selects and calculates over metrics. For Prometheus, Grafana understands a few special functions in that query; the one used most is `label_values(<metric>, <label>)`, which returns values of `<label>` on time series of `<metric>`.

A time series is one metric name with one set of labels, stored over time. `label_values()` is Grafana's classic variable syntax, rather than a PromQL function. Grafana 13.2 still accepts it in a dashboard file. In the variable editor, the newer **Label values** query type offers separate metric and label fields.

In a panel query, `$namespace` stands for the selected value. Grafana replaces it before it sends the query to Prometheus, so Prometheus never sees the variable, only `namespace="outpost"` or `namespace="starfleet"`.

The fields of a query variable:

| Field | What it does |
| --- | --- |
| `name` | The name used in queries as `$name` |
| `label` | The text shown next to the drop-down list |
| `type` | `query` fills the list from a data source; `custom` takes a fixed comma-separated list |
| `datasource` | The data source the variable query runs against |
| `query` | Here `label_values(http_requests_total, namespace)` |
| `refresh` | `1` refreshes the list when the dashboard loads, `2` also when the time range changes |
| `current` | The value selected when the dashboard opens |

## Add the variable

The new version of the ConfigMap has the same name, so applying it replaces the dashboard. It adds a `templating` block and changes `namespace=\"starfleet\"` to `namespace=\"$namespace\"` in all four queries. Nothing else changes.

<!-- astrona:playground:renew -->

Save this as `configmap-dashboard-starfleet-requests.yaml`, over the old file:

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
      "templating": {
        "list": [
          {
            "name": "namespace",
            "label": "Namespace",
            "type": "query",
            "datasource": {"type": "prometheus", "uid": "prometheus"},
            "query": "label_values(http_requests_total, namespace)",
            "refresh": 1,
            "current": {"text": "starfleet", "value": "starfleet"}
          }
        ]
      },
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
              "expr": "sum by (status) (rate(http_requests_total{namespace=\"$namespace\"}[1m]))",
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
              "expr": "sum(rate(http_requests_total{namespace=\"$namespace\", status=~\"5..\"}[1m])) / sum(rate(http_requests_total{namespace=\"$namespace\"}[1m]))"
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
              "expr": "histogram_quantile(0.5, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"$namespace\"}[5m])))",
              "legendFormat": "p50"
            },
            {
              "refId": "B",
              "expr": "histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"$namespace\"}[5m])))",
              "legendFormat": "p99"
            }
          ]
        }
      ]
    }
```

Apply it:

```sh
kubectl apply -f configmap-dashboard-starfleet-requests.yaml
```

## Check the variable and the queries

Then check the result. Give the sidecar a few seconds, then read the variable and the panel queries back from Grafana:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/starfleet-requests | jq '.dashboard.templating.list[] | {name, type, query, current}'
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/starfleet-requests |
  jq -r '.dashboard.panels[] | .title as $title | .targets[] | "\($title) [\(.refId)]: \(.expr)"'
```

You should see:

```text
{
  "name": "namespace",
  "type": "query",
  "query": "label_values(http_requests_total, namespace)",
  "current": {
    "text": "starfleet",
    "value": "starfleet"
  }
}
Request rate [A]: sum by (status) (rate(http_requests_total{namespace="$namespace"}[1m]))
Error ratio [A]: sum(rate(http_requests_total{namespace="$namespace", status=~"5.."}[1m])) / sum(rate(http_requests_total{namespace="$namespace"}[1m]))
Latency [A]: histogram_quantile(0.5, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="$namespace"}[5m])))
Latency [B]: histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="$namespace"}[5m])))
```

Grafana stores `$namespace` as it is. To see the values the drop-down list will offer, ask the Prometheus data source the same question `label_values()` asks. The data source has unique identifier (UID) `prometheus`. Grafana passes requests under `/api/datasources/uid/<uid>/resources/` to the data source, so this is the label values API of Prometheus, reached through Grafana:

```sh
curl -s -G -u admin:starfleet "http://127.0.0.1:3300/api/datasources/uid/prometheus/resources/api/v1/label/namespace/values" \
  --data-urlencode 'match[]=http_requests_total' | jq -c .
```

You should see:

```text
{"status":"success","data":["outpost","starfleet"]}
```

These two values are the drop-down list. Reload the dashboard in your browser, pick `outpost` in the **Namespace** list, and every panel redraws. To check what the panels run for `outpost`, send the queries with the value filled in, as Grafana does, using this helper. It sends an instant query through Grafana and prints labels and values; define it in this terminal:

```sh
grafana_query() {
  curl -s -u admin:starfleet -H 'Content-Type: application/json' http://127.0.0.1:3300/api/ds/query \
    -d "$(jq -n --arg expr "$1" '{from: "now-5m", to: "now", queries: [{refId: "A", datasource: {uid: "prometheus"}, expr: $expr, instant: true}]}')" |
    jq -r '.results.A.frames[] | "\(.schema.fields[1].labels // {} | to_entries | map("\(.key)=\(.value)") | join(","))\t\(.data.values[1][0])"'
}
```

Run the two expressions with the selected namespace filled in:

```sh
grafana_query 'sum by (status) (rate(http_requests_total{namespace="outpost"}[1m]))'
grafana_query 'sum(rate(http_requests_total{namespace="outpost", status=~"5.."}[1m])) / sum(rate(http_requests_total{namespace="outpost"}[1m]))'
```

You should see:

```text
status=200	0.9266399999999999
	null
```

`outpost` only gets normal requests, so there is a single line for `200`. The error ratio returns no data at all, which the helper prints as `null`. The selector `status=~"5.."` finds no series in `outpost`, so the top half of the division is empty, and an empty side makes the whole result empty. On the dashboard, the stat panel says "No data", not `0%`. That is correct PromQL behaviour, but it can scare an on-call engineer. If you want the panel to show `0` instead, add `or vector(0)` to the top half of the division, so it returns a zero series when there are no errors.

You can now make one dashboard serve every namespace with a query variable. The dashboard definition lives outside Grafana's database in a ConfigMap. The open question is what happens to a dashboard someone builds by clicking in the web interface, and how to bring it into a file.

## Common pitfalls

> [!WARNING]
> - **Forgetting `$` in one query.** That panel keeps showing the old namespace while the others switch. List all queries from the API after every change.
> - **Writing `namespace="$namespace"` without the escaped quotes in JSON.** Inside the JSON string it must be `namespace=\"$namespace\"`.
> - **Reading "No data" as zero.** An empty ratio means a side of the division has no series. Check each half on its own.
> - **A variable query on a metric that does not exist.** The drop-down list is then empty and every panel shows nothing. Test the `label_values()` metric name first.

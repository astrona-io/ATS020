# Solution

This walkthrough finds why the dashboard `scout-overview` is missing and why its panels would have no data, then fixes both faults in the ConfigMap. Run each step, then run `astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-01/labs/lab-01` to see which checks pass. In a second terminal, keep a port-forward to Grafana running:

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3300:80
```

## Step 1: Check that Grafana does not know the dashboard

Ask the Grafana application programming interface (API) for the dashboard:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/scout-overview | jq '{message}'
```

You should see:

```text
{
  "message": "Dashboard not found"
}
```

The ConfigMap exists, but Grafana has not loaded it. The dashboard sidecar, a second container in the Grafana pod, copies only ConfigMaps that carry a certain label.

## Step 2: Find the label the sidecar watches

Read the sidecar settings and the labels of the ConfigMap:

```sh
kubectl -n monitoring get deploy kps-grafana -o jsonpath='{range .spec.template.spec.containers[?(@.name=="grafana-sc-dashboard")].env[*]}{.name}={.value}{"\n"}{end}' | grep -E "^LABEL"
kubectl -n monitoring get configmap dashboard-scout-overview --show-labels
```

You should see:

```text
LABEL=grafana_dashboard
LABEL_VALUE=1
NAME                       DATA   AGE   LABELS
dashboard-scout-overview   1      8m    <none>
```

The sidecar asks for `grafana_dashboard=1` and the ConfigMap has no labels.

## Step 3: Label the ConfigMap

Add the label:

```sh
kubectl -n monitoring label configmap dashboard-scout-overview grafana_dashboard=1
```

You should see:

```text
configmap/dashboard-scout-overview labeled
```

Wait a few seconds. Then check that Grafana loads the dashboard and reports it as provisioned:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/scout-overview | jq '{uid: .dashboard.uid, provisioned: .meta.provisioned}'
```

You should see:

```text
{
  "uid": "scout-overview",
  "provisioned": true
}
```

The first check passes now. The dashboard exists, but its panels may still show nothing.

## Step 4: Find the data source UID the panels use

List the data source UIDs that the panels name, then list the data sources Grafana has:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/scout-overview | jq -c '[.dashboard.panels[].datasource.uid] | unique'
curl -s -u admin:starfleet http://127.0.0.1:3300/api/datasources | jq -c '.[] | {name, uid}'
```

You should see:

```text
["prometheus-main"]
{"name":"Prometheus","uid":"prometheus"}
```

Every panel points at `prometheus-main`, and the only data source has the UID `prometheus`. Grafana cannot find a data source with the first UID, so every query fails. The variable `namespace` uses the same wrong UID.

## Step 5: Fix the UID in the ConfigMap

Edit the ConfigMap and replace every `prometheus-main` with `prometheus`:

```sh
kubectl -n monitoring edit configmap dashboard-scout-overview
```

In the editor, replace all `"uid": "prometheus-main"` with `"uid": "prometheus"`. There are four places: three panels and the variable. Save and close the editor. Do not delete a panel, and do not add a data source with the UID `prometheus-main`.

Wait a few seconds, then check the UIDs again:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/scout-overview | jq -c '[.dashboard.panels[].datasource.uid] | unique'
```

You should see:

```text
["prometheus"]
```

## Step 6: Prove that the panels return data

Send each panel query through Grafana with `$namespace` set to `starfleet`. This helper sends an instant query and prints the first value of each series:

```sh
grafana_query() {
  curl -s -u admin:starfleet -H 'Content-Type: application/json' http://127.0.0.1:3300/api/ds/query \
    -d "$(jq -n --arg expr "$1" '{from: "now-5m", to: "now", queries: [{refId: "A", datasource: {uid: "prometheus"}, expr: $expr, instant: true}]}')" |
    jq -r '.results.A.frames[] | .data.values[1][0]'
}
grafana_query 'sum(rate(http_requests_total{namespace="starfleet"}[1m]))'
grafana_query 'sum(rate(http_requests_total{namespace="starfleet", status=~"5.."}[1m])) / sum(rate(http_requests_total{namespace="starfleet"}[1m]))'
grafana_query 'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m])))'
```

You should see three numbers: the request rate, the error ratio and the p99 latency. Your numbers will differ:

```text
1.5333333333333332
0.11594202898550725
2.2286548525878933
```

Each panel query returns data, so the panels draw lines and numbers. Run `astrona submit` now: all three checks pass.

## Wrong fixes the grader rejects

- Saving the dashboard with `POST /api/dashboards/db` or in the web interface. Grafana stores it in its database, `meta.provisioned` stays `false`, and a new pod loses it.
- Creating a data source with the UID `prometheus-main` in the web interface. The panels work, but the data source is not read-only, so it is not provisioned from a ConfigMap.
- Deleting the panels that show no data. The grader requires `Request rate`, `Error ratio` and `Latency`.

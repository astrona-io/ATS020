# Overview: Build Grafana Dashboards As Code (Playground)

This playground gives you live request metrics and an empty Grafana instance.
A Grafana dashboard is a set of panels that query a data source and draw the
results. You create the data source and dashboard through Kubernetes
ConfigMaps, objects that store configuration text. There is no grading.

## What's in the box

The cluster runs Kubernetes 1.35.8. The `monitoring` namespace holds
Prometheus 3.15.0, the Prometheus Operator 0.94.1 and Grafana 13.2.3.
Grafana has sidecar containers that copy labelled ConfigMaps into its
provisioning directories. Provisioning means loading settings from files.
Default dashboards and the default data source are disabled.

| Namespace | Contents |
| --- | --- |
| `starfleet` | Two `scout` pods, their Service and ServiceMonitor, and the `shuttle` traffic client |
| `outpost` | One `scout` pod, its Service and ServiceMonitor |

A ServiceMonitor tells the Prometheus Operator which Service endpoints to
scrape. Both monitors carry `release: kps`, which the Prometheus resource
selects. The client sends normal requests to both namespaces, plus errors
and delayed requests to `starfleet`. Alertmanager and exporters for nodes
and Kubernetes objects are disabled to save memory.

## Helpers

Use a second terminal for each port-forward and leave them running:

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3300:80
```

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Open `http://127.0.0.1:3300` and sign in as `admin` with password `starfleet`.
The password belongs to this disposable playground. Prometheus is at
`http://127.0.0.1:9090`.

These helpers use `curl` and `jq` on your machine. The first lists data
sources through the Grafana application programming interface (API). The
second runs a Prometheus Query Language (PromQL) expression:

```sh
show_data_sources() {
  curl -fsS -u admin:starfleet http://127.0.0.1:3300/api/datasources |
    jq '.[] | {name, uid, type, url}'
}
query_prometheus() {
  curl -fsS http://127.0.0.1:9090/api/v1/query \
    --data-urlencode "query=$1" | jq '.data.result'
}
```

## Practice tasks

- Provision a Prometheus data source with a fixed unique identifier and check its health in Grafana.
- Create request-rate, error-ratio and latency panels. Set a unit for each result.
- Add a namespace variable and switch every panel between `starfleet` and `outpost`.
- Export a dashboard, store it in a labelled ConfigMap, restart Grafana and prove the dashboard returns.
- Change one ConfigMap label so the sidecar ignores it. Use the sidecar logs to find why the dashboard is missing.

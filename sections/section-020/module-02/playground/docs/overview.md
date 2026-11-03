# Overview: Collect Pod Logs With The OpenTelemetry Collector (Playground)

This playground gives you pods that write log lines and no log pipeline. A log pipeline is the chain of parts that reads log lines, adds data to them and sends them on. You build it with the OpenTelemetry Collector, a program that receives, processes and exports telemetry. There is no grading.

## What's in the box

The cluster runs Kubernetes 1.35.8. The `monitoring` namespace holds Prometheus 3.15.0 and the Prometheus Operator 0.94.1. Alertmanager, Grafana and the exporters for nodes and Kubernetes objects are disabled to save memory. The `cert-manager` namespace holds cert-manager 1.21.2, which the OpenTelemetry Operator 0.160.0 needs for its webhook certificate. The operator turns an `OpenTelemetryCollector` resource into a running Collector. The image `otel/opentelemetry-collector-contrib:0.162.0` is already on the node.

| Namespace | Contents |
| --- | --- |
| `starfleet` | `scout` (one pod of `podinfo` 6.15.0) and the `shuttle` traffic client |
| `outpost` | `probe` (one pod of `go-httpbin` 2.25.0), which logs one line per request |

Every second `shuttle` sends one request to `scout` and one to `probe`. Every fourth second it also asks `probe` for `/status/500`, so `probe` logs both normal lines and lines with `level=ERROR`. Prometheus selects a ServiceMonitor or PodMonitor only when it carries the label `release: kps`.

## Helpers

Read the logs of a pod with `kubectl logs`:

```sh
kubectl -n outpost logs deploy/probe --tail=5
```

Use a second terminal for the Prometheus port-forward and leave it running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

This helper runs a Prometheus Query Language (PromQL) expression through the Prometheus HTTP API with `curl` and `jq` on your machine:

```sh
query_prometheus() {
  curl -fsS http://127.0.0.1:9090/api/v1/query \
    --data-urlencode "query=$1" | jq '.data.result'
}
```

## Practice tasks

- Read the logs, the previous logs and the events of a pod with `kubectl`.
- Deploy a Collector as a DaemonSet that reads the container log files on the node, and prove it with the debug exporter.
- Add the pod name and namespace to each log record, and drop the records of one namespace.
- Count the error lines of `probe` into a metric, scrape it with a ServiceMonitor and query it.
- Remove a permission from the Collector's ClusterRole and find the error in the Collector's own logs.

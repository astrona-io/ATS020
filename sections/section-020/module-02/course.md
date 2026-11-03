# Collect Pod Logs With The OpenTelemetry Collector

Kubernetes keeps the log of every container, and `kubectl logs` reads it. That works for one pod at a time while the pod is alive. It does not work when a team asks how many errors a Deployment logged in the last hour, or when a pod has been deleted. A platform needs a log pipeline that reads the log lines on every node, adds the pod and Deployment name to each one, and turns the lines that matter into a metric.

The OpenTelemetry Collector is a program that receives, processes and exports telemetry: metrics, logs and traces. In this module a Collector runs as a DaemonSet, a workload that runs one pod on every node. It reads the container log files, adds Kubernetes data, drops the lines nobody needs and counts the error lines into a Prometheus metric. There is no Loki and no LogQL here. The Collector and Prometheus do the whole job.

Keep one sentence in mind for this module: **a log pipeline reads the files on each node, and a count connector turns error lines into a metric that Prometheus can alert on.**

The module has four parts. **What Kubernetes Keeps About Logs** reads the logs, the previous logs and the events of a crashing pod, and shows where these tools stop. **A DaemonSet Collector Reads The Log Files** shows where container logs live on a node and deploys a Collector with the `file_log` receiver. **Add Kubernetes Metadata And Drop Records** adds the Deployment and node name with the `k8s_attributes` processor, fixes the permission error that comes with it and drops `INFO` lines. **Count Error Lines Into A Prometheus Metric** counts the `ERROR` lines, scrapes the count with a ServiceMonitor and queries it. A graded lab follows the last part.

## Learning objectives

After this module you can:

- Read a pod's logs, its previous container's logs and its events with `kubectl logs` and `kubectl events`.
- Deploy an OpenTelemetry Collector as a DaemonSet whose `file_log` receiver reads the container log files on each node.
- Add Kubernetes metadata to each log record with the `k8s_attributes` processor, and drop unwanted records with the `filter` processor.
- Check the logs pipeline with the debug exporter and the Collector's own log, and read a permission error.
- Turn error log lines into a Prometheus metric with the count connector and query it with PromQL.

## Before you start

You need Kubernetes basics (`kubectl get`, `kubectl logs`, `kubectl apply`), a first look at RBAC (Role-Based Access Control: ClusterRole and ClusterRoleBinding), and PromQL (Prometheus Query Language) at the level of `rate()` and `sum by`.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. The namespace `monitoring` holds one Prometheus server (version 3.15.0, Service `kps-prometheus` on port `9090`) with the Prometheus Operator. Alertmanager, Grafana and the node and object exporters are not installed. The namespace `cert-manager` holds cert-manager, which the OpenTelemetry Operator 0.160.0 needs for its webhook certificate. The operator turns an `OpenTelemetryCollector` resource into a running Collector. No Collector exists yet. The Collector image is `otel/opentelemetry-collector-contrib:0.162.0`.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | One pod of `podinfo` 6.15.0. It writes almost no log lines |
| `starfleet` | `shuttle` | A client pod that sends one request per second to `scout` and to `probe`, and a `/status/500` request to `probe` every fourth second |
| `outpost` | `probe` | One pod of `go-httpbin` 2.25.0. It logs one line per request, with `level=ERROR` for a `5xx` response |

A ServiceMonitor tells the Prometheus Operator which Service endpoints to scrape. Prometheus selects only ServiceMonitors that carry the label `release: kps`. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-02/playground
> ```

# Collect Pod Logs With The OpenTelemetry Collector

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 3 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| What Kubernetes Keeps About Logs | Explore in the playground; apply this preparation in the following labs |
| A DaemonSet Collector Reads The Log Files | Repair Container Log File Collection |
| Add Kubernetes Metadata And Drop Records | Restore Collector Kubernetes Metadata |
| Count Error Lines Into A Prometheus Metric | Scrape Collector Error Metrics |

## What you will prove

- Repair Container Log File Collection.
- Restore Collector Kubernetes Metadata.
- Scrape Collector Error Metrics.

## Before you start

You need Kubernetes basics (`kubectl get`, `kubectl logs`, `kubectl apply`), a first look at RBAC (Role-Based Access Control: ClusterRole and ClusterRoleBinding), and PromQL (Prometheus Query Language) at the level of `rate()` and `sum by`.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. The namespace `monitoring` holds one Prometheus server (version 3.15.0, Service `kps-prometheus` on port `9090`) with the Prometheus Operator. Alertmanager, Grafana and the node and object exporters are not installed. The namespace `cert-manager` holds cert-manager, which the OpenTelemetry Operator 0.163.0 needs for its webhook certificate. The operator turns an `OpenTelemetryCollector` resource into a running Collector. No Collector exists yet. The Collector image is `otel/opentelemetry-collector-contrib:0.165.0`.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | One pod of `podinfo` 6.17.0. It writes almost no log lines |
| `starfleet` | `shuttle` | A client pod that sends one request per second to `scout` and to `probe`, and a `/status/500` request to `probe` every fourth second |
| `outpost` | `probe` | One pod of `go-httpbin` 2.25.0. It logs one line per request, with `level=ERROR` for a `5xx` response |

A ServiceMonitor tells the Prometheus Operator which Service endpoints to scrape. Prometheus selects only ServiceMonitors that carry the label `release: kps`. Reading commands use this playground unless the page explicitly starts an independent lab.

Launch the playground for the reading exercises:

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-20/playground
> ```

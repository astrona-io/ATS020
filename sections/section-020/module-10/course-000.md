# Build Grafana Dashboards As Code

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 6 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| Grafana's Parts And A Provisioned Data Source | Provision The Prometheus Data Source |
| Panels For Rate, Error Ratio And Latency | Explore in the playground; apply this preparation in the following labs |
| A Namespace Variable For Every Panel | Repair Dashboard Data Source References |
| Dashboards That Survive A Restart | Restore Dashboard Provisioning |
| Restore Grafana Writable Storage | Restore Grafana Writable Storage |
| Repair Grafana Secret Keys | Repair Grafana Secret Keys |
| Size Grafana Memory For Startup | Size Grafana Memory For Startup |

## What you will prove

- Provision The Prometheus Data Source.
- Repair Dashboard Data Source References.
- Restore Dashboard Provisioning.
- Restore Grafana Writable Storage.
- Repair Grafana Secret Keys.
- Size Grafana Memory For Startup.

## Before you start

You need Kubernetes basics, `kubectl port-forward` and `kubectl logs`, and `curl` and `jq` on your machine. You need to read PromQL (Prometheus Query Language): a `rate()` of a counter, an error ratio built from two sums, and a `histogram_quantile()` over histogram buckets.

Your playground is a single-node `kind` cluster running Kubernetes 1.35, with a trimmed Prometheus stack in the namespace `monitoring`: the Prometheus Operator, one Prometheus server (version 3.15.0, Service `kps-prometheus` on port `9090`) and Grafana 13.2.3 (Service `kps-grafana` on port `80`). Alertmanager and the exporters for node and Kubernetes object metrics are disabled. Grafana has no data source and no dashboard yet; the default data source and default dashboards are switched off.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | Two pods of `podinfo` 6.17.0, scraped by a ServiceMonitor |
| `starfleet` | `shuttle` | A client pod that sends normal requests to each `scout`, plus a `/status/500` every fifth loop and a `/delay/1` every tenth loop to the `starfleet` `scout` |
| `outpost` | `scout` | One pod of `podinfo` 6.17.0, scraped by a ServiceMonitor. It only gets normal requests |

A namespace groups Kubernetes resources. A ServiceMonitor tells the Prometheus Operator which Service endpoints to scrape; both monitors carry the selected label `release: kps`. The Grafana user is `admin` with the password `starfleet`. Reading commands use this playground unless the page explicitly starts an independent lab.

Launch the playground for the reading exercises:

<!-- astrona:playground -->

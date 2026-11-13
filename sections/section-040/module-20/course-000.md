# Measure Service Levels And Resource Efficiency

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 4 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| SLI, SLO And Error Budget From Request Counters | Record Availability And Error Budget |
| Burn-Rate Alerts With Two Windows | Repair A Multi-Window Burn-Rate Alert |
| Requests Versus Usage With kubectl top And Prometheus | Explore in the playground; apply this preparation in the following labs |
| Reduce Excess Resource Requests | Reduce Excess Resource Requests |
| Raise An Undersized Memory Request | Raise An Undersized Memory Request |

## What you will prove

- Record Availability And Error Budget.
- Repair A Multi-Window Burn-Rate Alert.
- Reduce Excess Resource Requests.
- Raise An Undersized Memory Request.

## Before you start

You need to write a basic PromQL query with `rate()` and `sum`, apply a Kubernetes resource with `kubectl apply`, and use `kubectl port-forward`. You also need `curl` and `jq` on your machine. You do not need to know metrics-server or kube-state-metrics. The module explains the parts it uses.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It starts in a few minutes.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `kube-system` | `metrics-server` | metrics-server 0.9.0, so `kubectl top` works |
| `monitoring` | `prometheus-kps-prometheus` | One Prometheus (Prometheus Operator, kube-prometheus-stack 93.3.0). It scrapes every 15 seconds and keeps 6 hours of data. kube-state-metrics and the kubelet scrape job (cAdvisor) are installed, because the module needs them. Alertmanager, Grafana and node exporter are not installed |
| `starfleet` | `scout`, `probe`, `shuttle` | `scout` requests far more than it uses. `probe` requests less than it uses. `shuttle` runs a traffic loop that makes about 5 percent of the requests to `scout` fail |

The numbers and pod names in the output of this module come from one run. Your playground makes new ones, so your values differ.

Launch the playground for the reading exercises:

<!-- astrona:playground -->

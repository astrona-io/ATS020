# Measure Service Levels And Resource Efficiency

A platform team answers two questions about every service: does it work well enough, and does it cost more than it needs? The first question is about a service level, a promise about how often requests succeed. The second question is about efficiency, the gap between the CPU and memory that a workload reserves and the CPU and memory that it uses. Both answers come from numbers that the cluster already produces.

This module measures the first question with a request counter in Prometheus. It turns the counter into a service level indicator, compares it with a target and alerts when the budget for failures burns too fast. Then it measures the second question with metrics-server, cAdvisor and kube-state-metrics, and it changes the requests of two workloads until the gap closes. The exam asks for both: a PromQL query that returns the right number, and a fix that you prove with a measurement.

The module has four parts. **SLI, SLO And Error Budget From Request Counters** defines the three terms and calculates them for `scout`. **Burn-Rate Alerts With Two Windows** writes an alert on how fast the budget burns and ends with a graded lab. **Requests Versus Usage With kubectl top And Prometheus** reads what each container requested and what it uses. **Find And Fix Over- And Under-Provisioned Workloads** ranks the gap, changes the requests and ends with a second graded lab.

## Learning objectives

After this module you can:

- Write an SLI as a PromQL ratio of good requests to all requests.
- Calculate the remaining error budget for a 99 percent SLO over a window.
- Write a burn-rate alert with two windows that fires when the budget would run out early.
- Compare container CPU and memory requests with real usage from metrics-server and Prometheus.
- Name the workload with the biggest gap and change its requests to match usage.

## Before you start

You need to write a basic PromQL query with `rate()` and `sum`, apply a Kubernetes resource with `kubectl apply`, and use `kubectl port-forward`. You also need `curl` and `jq` on your machine. You do not need to know metrics-server or kube-state-metrics. The module explains the parts it uses.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It starts in a few minutes.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `kube-system` | `metrics-server` | metrics-server 0.9.0, so `kubectl top` works |
| `monitoring` | `prometheus-kps-prometheus` | One Prometheus (Prometheus Operator, kube-prometheus-stack 92.3.0). It scrapes every 15 seconds and keeps 6 hours of data. kube-state-metrics and the kubelet scrape job (cAdvisor) are installed, because the module needs them. Alertmanager, Grafana and node exporter are not installed |
| `starfleet` | `scout`, `probe`, `shuttle` | `scout` requests far more than it uses. `probe` requests less than it uses. `shuttle` runs a traffic loop that makes about 5 percent of the requests to `scout` fail |

The numbers and pod names in the output of this module come from one run. Your playground makes new ones, so your values differ.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

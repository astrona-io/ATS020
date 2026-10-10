# Query Metrics With PromQL

Once Prometheus collects a workload's metrics, every question about that workload becomes a query. How many requests per second does it serve? What share of them fail? How slow is the slowest five percent? Dashboards, alerts and service level objectives are all built from the answers, so a wrong query gives a wrong dashboard, a silent alert and a false report.

PromQL, the Prometheus Query Language, is the language Prometheus uses to select, filter and calculate over its stored data. A query is short, but each part changes the meaning: the type of the metric, the time range in square brackets, and which labels an aggregation keeps. The exam asks for a query that returns the right number, so the details matter.

Keep one sentence in mind for this module: **select the series, turn counters into rates, then aggregate to the labels you need.** Almost every useful query follows that order.

The module has four parts. **Selecting Time Series** shows what a query returns and how label matchers pick series. **Counters, Gauges And rate()** explains the metric types in `scout`'s own metrics and why `rate()` only belongs on counters. **Aggregation, Error Ratio And Latency** sums series by label and builds the two queries every alert and objective reuses: the error ratio and a latency percentile. **Running Queries From The Command Line** sends queries to the Prometheus HTTP API and reads the JSON it returns.

## Learning objectives

After this module you can:

- Select time series by metric name and label matchers, including regular expression matchers.
- Calculate a per-second request rate from a counter with `rate()`, and explain why `rate()` is not used on a gauge.
- Aggregate series with `sum by` and `sum without` to get one value per namespace or per status code.
- Calculate an error ratio and a 95th-percentile latency with `histogram_quantile`.
- Run a query from the command line against the Prometheus HTTP API and read the result with `jq`.

## Before you start

You need Kubernetes basics and `kubectl port-forward`, and `jq` on your machine. You need to know that Prometheus scrapes targets and stores what it reads as time series with labels. This module does not set up scraping; the playground has it ready.

Your playground is a single-node `kind` cluster running Kubernetes 1.35, with a trimmed Prometheus stack in the namespace `monitoring`: the Prometheus Operator and one Prometheus server, version 3.15.0, behind the Service `kps-prometheus` on port `9090`. Prometheus scrapes every 15 seconds. The workloads are already scraped, and traffic is already flowing:

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | Two pods of `podinfo` 6.15.0, a small web application that serves its own metrics. A ServiceMonitor collects them |
| `outpost` | `scout` | One more `podinfo` pod, also collected by a ServiceMonitor |
| `starfleet` | `shuttle` | A client pod that runs a traffic loop: every second one request to each `scout`, every fifth second one request to `/status/500` on the `starfleet` `scout` (which answers `500`), and every tenth second one request to `/delay/1` (which waits one second) |

Because of that loop, the `starfleet` `scout` always has some failed and some slow requests, so the error and latency queries return real numbers. Wait five minutes after the playground starts before you run queries with `[5m]`, so the time range is filled with data. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

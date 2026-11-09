# Query Metrics With PromQL

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 2 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| Selecting Time Series | Explore in the playground; apply this preparation in the following labs |
| Counters, Gauges And rate() | Explore in the playground; apply this preparation in the following labs |
| Aggregate Requests And Record An Error Ratio | Repair An Error Ratio Recording Rule |
| Calculate A Latency Percentile | Repair A Latency Percentile Recording Rule |
| Running Queries From The Command Line | Explore in the playground; apply this preparation in the following labs |

## What you will prove

- Repair An Error Ratio Recording Rule.
- Repair A Latency Percentile Recording Rule.

## Before you start

You need Kubernetes basics and `kubectl port-forward`, and `jq` on your machine. You need to know that Prometheus scrapes targets and stores what it reads as time series with labels. This module does not set up scraping; the playground has it ready.

Your playground is a single-node `kind` cluster running Kubernetes 1.35, with a trimmed Prometheus stack in the namespace `monitoring`: the Prometheus Operator and one Prometheus server, version 3.15.0, behind the Service `kps-prometheus` on port `9090`. Prometheus scrapes every 15 seconds. The workloads are already scraped, and traffic is already flowing:

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | Two pods of `podinfo` 6.17.0, a small web application that serves its own metrics. A ServiceMonitor collects them |
| `outpost` | `scout` | One more `podinfo` pod, also collected by a ServiceMonitor |
| `starfleet` | `shuttle` | A client pod that runs a traffic loop: every second one request to each `scout`, every fifth second one request to `/status/500` on the `starfleet` `scout` (which answers `500`), and every tenth second one request to `/delay/1` (which waits one second) |

Because of that loop, the `starfleet` `scout` always has some failed and some slow requests, so the error and latency queries return real numbers. Wait five minutes after the playground starts before you run queries with `[5m]`, so the time range is filled with data. Reading commands use this playground unless the page explicitly starts an independent lab.

Launch the playground for the reading exercises:

<!-- astrona:playground -->

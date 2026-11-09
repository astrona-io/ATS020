# Query Logs With Loki And LogQL

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 2 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| Connect Grafana To Loki | Explore in the playground; apply this preparation in the following labs |
| Query Logs With LogQL | Explore in the playground; apply this preparation in the following labs |
| Repair And Save A Loki Dashboard | Repair A Loki Error Dashboard |
| Use Log Evidence To Stop Failing Workloads | Find And Stop Error-Logging Workloads |

## What you will prove

- Repair A Loki Error Dashboard.
- Find And Stop Error-Logging Workloads.

## Before you start

You need `kubectl get`, `scale` and `port-forward`, `curl`, basic `jq`, and the idea of a **Grafana dashboard**, a set of panels that each run a query against a **data source**, the connection Grafana uses to read data. A **controller** is a Kubernetes object that keeps Pods running, such as a Deployment or a StatefulSet.

The playground runs Kubernetes 1.35.8, Grafana 13.2.3 and Loki 3.7.9. An OpenTelemetry Collector DaemonSet in `logging` sends the logs of `outpost` and `starfleet` to Loki. It is plumbing and needs no attention. `outpost` holds the Deployments `probe`, `beacon` and `scout` and the StatefulSet `depot`. `starfleet` holds the Deployments `relay` and `shuttle`. Grafana has a saved dashboard named `Outpost Logs`, and no data source yet. Its user is `admin` and its password is `starfleet`.

Write the example files in an empty working folder.

<!-- astrona:playground -->

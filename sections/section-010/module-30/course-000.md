# Alert With PrometheusRule And Alertmanager

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 5 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| Recording And Alerting Rules | Explore in the playground; apply this preparation in the following labs |
| Selecting And Loading PrometheusRules | Explore in the playground; apply this preparation in the following labs |
| The Alert Lifecycle | Create And Verify An Alerting Rule |
| Routing Alerts With Alertmanager | Route An Alert To Its Receiver |
| Silences | Silence A Maintenance Alert |
| Inhibition | Inhibit A Related Warning Alert |
| Route Precedence And Grouping | Repair Route Precedence And Grouping |

## What you will prove

- Create And Verify An Alerting Rule.
- Route An Alert To Its Receiver.
- Silence A Maintenance Alert.
- Inhibit A Related Warning Alert.
- Repair Route Precedence And Grouping.

## Before you start

You need Kubernetes basics and `kubectl port-forward`, `kubectl exec` and `kubectl logs`, and `jq` on your machine. You need to read a PromQL error ratio: the sum of the rates of failed requests divided by the sum of the rates of all requests.

Your playground is a single-node `kind` cluster running Kubernetes 1.35, with a trimmed Prometheus stack in the namespace `monitoring`: the Prometheus Operator, one Prometheus server (version 3.15.0, Service `kps-prometheus` on port `9090`) and one Alertmanager (version 0.34.1, Service `kps-alertmanager` on port `9093`). Alertmanager still has the Helm chart's default configuration, which sends every alert to a receiver called `null` that does nothing.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | Two pods of `podinfo` 6.17.0, already scraped by a ServiceMonitor. A request to `/status/500` makes it answer `500` |
| `starfleet` | `shuttle` | A client pod that sends one normal request per second to `scout`, so there are no errors until you cause them |
| `monitoring` | `alert-receiver` | A small HTTP server on port `8080` that prints one line for every alert in every notification it receives. It stands in for a chat or paging service |

No PrometheusRule or AlertmanagerConfig for the Starfleet app exists yet. Reading commands use this playground unless the page explicitly starts an independent lab.

Launch the playground for the reading exercises:

<!-- astrona:playground -->

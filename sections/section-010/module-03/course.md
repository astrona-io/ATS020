# Alert With PrometheusRule And Alertmanager

A query tells you what is wrong when you ask. An alert tells you without being asked, at three in the morning, and only when it matters. Getting there takes two components that are easy to mix up: Prometheus decides **that** something is wrong, and Alertmanager decides **who hears about it and how often**.

On a cluster run by the Prometheus Operator, both halves are custom resources. A **PrometheusRule** holds the queries Prometheus evaluates on a schedule, either to store a result as a new series or to raise an alert. An **AlertmanagerConfig** tells Alertmanager which alerts go to which receiver. Each resource is only read if the right selector picks it up, and each change takes effect a little later than you expect.

Keep one sentence in mind for this module: **Prometheus fires alerts, Alertmanager routes, groups and silences them.** When an alert does not arrive, first find out which of the two dropped it.

The module has four parts. **Recording And Alerting Rules** writes a PrometheusRule with a recording rule for the `scout` error ratio and an alert on top of it. **The Alert Lifecycle** causes errors and follows the alert from `inactive` through `pending` to `firing` and back. **Routing Alerts With Alertmanager** sends the alert to a webhook receiver with an AlertmanagerConfig, and shows what the operator adds to every such route. **Silences And Inhibition** mutes the alert for a planned window and proves that no notification goes out.

## Learning objectives

After this module you can:

- Write an alerting rule in a PrometheusRule with `expr`, `for`, labels and annotations.
- Write a recording rule and query the new series it creates.
- Read an alert's state (`inactive`, `pending`, `firing`) in Prometheus and in Alertmanager.
- Route alerts by label to a receiver with an AlertmanagerConfig.
- Silence an alert for a time window and prove it stops notifying.

## Before you start

You need Kubernetes basics and `kubectl port-forward`, `kubectl exec` and `kubectl logs`, and `jq` on your machine. You need to read a PromQL error ratio: the sum of the rates of failed requests divided by the sum of the rates of all requests.

Your playground is a single-node `kind` cluster running Kubernetes 1.35, with a trimmed Prometheus stack in the namespace `monitoring`: the Prometheus Operator, one Prometheus server (version 3.15.0, Service `kps-prometheus` on port `9090`) and one Alertmanager (version 0.34.1, Service `kps-alertmanager` on port `9093`). Alertmanager still has the Helm chart's default configuration, which sends every alert to a receiver called `null` that does nothing.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | Two pods of `podinfo` 6.15.0, already scraped by a ServiceMonitor. A request to `/status/500` makes it answer `500` |
| `starfleet` | `shuttle` | A client pod that sends one normal request per second to `scout`, so there are no errors until you cause them |
| `monitoring` | `alert-receiver` | A small HTTP server on port `8080` that prints one line for every alert in every notification it receives. It stands in for a chat or paging service |

No PrometheusRule or AlertmanagerConfig for the Starfleet app exists yet. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

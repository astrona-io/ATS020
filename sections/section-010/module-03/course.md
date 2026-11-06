# Alert With PrometheusRule And Alertmanager

A query tells you what is wrong when you ask. An alert tells you without being asked, at three in the morning, and only when it matters. Getting there takes two components that are easy to mix up: Prometheus decides **that** something is wrong, and Alertmanager decides **who hears about it and how often**.

On a cluster run by the Prometheus Operator, both halves are custom resources. A **PrometheusRule** holds the queries Prometheus evaluates on a schedule, either to store a result as a new series or to raise an alert. An **AlertmanagerConfig** tells Alertmanager which alerts go to which receiver. Each resource is only read if the right selector picks it up, and each change takes effect a little later than you expect.

Keep one sentence in mind for this module: **Prometheus fires alerts, Alertmanager routes, groups and silences them.** When an alert does not arrive, first find out which of the two dropped it.

The module has seven parts, in the order an alert travels. **Recording And Alerting Rules** writes a PrometheusRule with a recording rule for the `scout` error ratio and an alert on top of it. **Selecting And Loading PrometheusRules** follows that object through the operator's two selectors, validation, the generated ConfigMap and the reload, and breaks the path with a wrong label to show where a rule gets lost. **The Alert Lifecycle** causes errors and follows the alert from `inactive` through `pending` to `firing` and into Alertmanager, with the timers and the send path that explain every delay. **Routing Alerts With Alertmanager** sends the alert to a webhook receiver with an AlertmanagerConfig, and shows what the operator adds to every such route.

**Silences** mutes the alert for a planned window, places the silence in Alertmanager's notification pipeline and proves from the receiver that nothing goes out. **Inhibition** writes a rule that mutes a warning alert while a critical one fires, and tells `inhibitedBy` from `silencedBy`. **Route Precedence And Grouping** builds a tree with three receivers, states the matching order with its tie-breaks, the grouping timers and the operator's merge order, and proves the result in the receiver log. The graded lab then asks you to load a team alert, route it to a webhook and silence a separate maintenance alert.

## Learning objectives

After this module you can:

- Write an alerting rule in a PrometheusRule with `expr`, `for`, labels and annotations.
- Write a recording rule and query the new series it creates.
- Follow a PrometheusRule from `kubectl apply` to the rules API and tell a selector mismatch from a rejected rule and an evaluation error.
- Read an alert's state (`inactive`, `pending`, `firing`) in Prometheus and (`active`, `suppressed`) in Alertmanager, and explain the delay between them.
- Route alerts by label to a receiver with an AlertmanagerConfig and read the matcher, receiver name and `continue` the operator adds.
- Silence an alert for a time window and prove from the receiver that it stops notifying.
- Write an inhibition rule and name every reason an alert is suppressed from `silencedBy` and `inhibitedBy`.
- Predict which receivers a route tree selects from matcher order, `continue` and inheritance, and when a group is sent and repeated.

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

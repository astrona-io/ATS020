# Overview: Alert With PrometheusRule And Alertmanager (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Prometheus, Alertmanager, a monitored web application and a webhook that prints every notification it receives, and then waits. There is no task, no `astrona submit` and no pass or fail. Write rules and routes, cause errors, silence alerts, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it. You also need `jq` on your machine.
- A trimmed Prometheus stack in `monitoring`: the Prometheus Operator, one Prometheus (version 3.15.0, Service `kps-prometheus` on `9090`) and one Alertmanager (version 0.34.1, Service `kps-alertmanager` on `9093`). Prometheus loads PrometheusRules with the label `release: kps`. Alertmanager reads AlertmanagerConfigs from every namespace, and its own default route sends everything to a receiver called `null` that does nothing.

  | Namespace | Workload | What it is |
  | --- | --- | --- |
  | `starfleet` | `scout` | Two `podinfo` pods scraped by a ServiceMonitor; `/status/500` makes them answer `500` |
  | `starfleet` | `shuttle` | A client sending one healthy request per second to `scout` |
  | `monitoring` | `alert-receiver` | An HTTP server on port `8080` that prints one line per alert in each webhook notification; read it with `kubectl -n monitoring logs deploy/alert-receiver` |

- No PrometheusRule or AlertmanagerConfig for the Starfleet app exists yet.

## Helpers

Start two port-forwards in other terminals and leave them running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
kubectl -n monitoring port-forward svc/kps-alertmanager 9093:9093
```

Then paste these once in each new terminal. `show_alerts` prints the alerts Prometheus holds and their state; `show_am_alerts` prints the alerts Alertmanager holds, their state and receivers; `make_errors` sends one failing request per second to `scout` for ten minutes (it keeps the terminal busy).

```sh
show_alerts() {
  curl -s http://127.0.0.1:9090/api/v1/alerts |
    jq -r '.data.alerts[] | "\(.labels.alertname)\t\(.state)\t\(.activeAt)\t\(.value)"'
}
show_am_alerts() {
  curl -s http://127.0.0.1:9093/api/v2/alerts |
    jq -r '.[] | "\(.labels.alertname)\t\(.status.state)\t\(.receivers | map(.name) | join(","))"'
}
make_errors() {
  kubectl -n starfleet exec deploy/shuttle -- sh -c 'for i in $(seq 1 600); do curl -s -o /dev/null http://scout.starfleet:9898/status/500; sleep 1; done'
}
```

## Practice tasks

- Write an alert on the error ratio with `for: 2m` and time how long it takes from `make_errors` to `firing`. Explain the total from the scrape interval, the evaluation interval and `for`.
- Put an AlertmanagerConfig in `monitoring` instead of `starfleet` and find out from the running configuration why the `starfleet` alert no longer reaches the webhook.
- Change `groupBy` to `["namespace"]`, add a second alert in the same rule group, and count how many notifications one incident sends.
- Silence the alert with only `alertname` as matcher, then with `alertname` and `namespace`, and compare what each would mute.
- Add a `critical` version of the alert with a higher threshold and watch the chart's inhibition rule mute the `warning` one.

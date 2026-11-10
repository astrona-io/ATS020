# Question

Solve this question on: `terminal`

The namespace `frontier` runs the workload `scout` with two pods behind the Service `scout`. The Service has the label `app: scout` and one port named `http`. The pods serve Prometheus metrics on the path `/metrics`. The pod `shuttle` in `frontier` sends steady traffic, and about one request in six fails with status `500`.

The platform team wants an alert when `scout` in `frontier` fails more than 5% of its requests for one minute. The alert must reach the webhook receiver. They applied three objects in `frontier`: the ServiceMonitor `scout`, the PrometheusRule `scout` and the AlertmanagerConfig `frontier`. Nothing works yet. Prometheus and Alertmanager run in the namespace `monitoring`. Prometheus is the Service `kps-prometheus` on port `9090`, Alertmanager is `kps-alertmanager` on port `9093`, and the receiver is the Service `alert-receiver` on port `8080`. The receiver prints one log line for each alert it gets.

## Tasks

1. Prometheus shows no `scout` target for `frontier`. Fix the ServiceMonitor `scout` until Prometheus scrapes both pods and `up{job="scout",namespace="frontier"}` is `1` for each pod.
2. The recording rule `namespace:http_requests_error_ratio:rate1m` returns no series. It must return the share of `scout` requests with a `5xx` status, for each namespace. Fix the PrometheusRule `scout` so the series exists for `frontier` and shows the real error ratio.
3. The alert `ScoutHighErrorRatio` must fire when that ratio is above 5% for one minute. Fix the alert in the PrometheusRule `scout` so that it fires for `frontier`.
4. The alert must reach the receiver. Alertmanager must route every alert with the label `team: frontier` to the webhook receiver. Fix the AlertmanagerConfig `frontier` until the log of the receiver shows `firing ScoutHighErrorRatio namespace=frontier`.

## Constraints

- Keep the ServiceMonitor, the PrometheusRule and the AlertmanagerConfig in the namespace `frontier`, with their names. Do not delete them.
- Do not change the Prometheus resource `kps-prometheus`, the Alertmanager resource, the Service `scout`, the Deployments in `frontier` or the Service `alert-receiver`.
- Keep the recording rule name `namespace:http_requests_error_ratio:rate1m`. The alert must use that recorded series.
- Keep the label `team: frontier` on the alert. Do not make the alert fire by writing a fixed value in an expression.

# Summary

A service level has three parts. The service level indicator (SLI) is a measured number, such as the share of requests that did not end with a `5xx` status. The service level objective (SLO) is the target for that number, such as 99 percent. The error budget is what the target still allows: with a 99 percent SLO, 1 percent of the requests may fail. The remaining budget is `1 - (1 - SLI) / (1 - SLO)`. It is `1` when no request failed, `0` when the budget is used up and negative when the service failed more than the SLO allows.

The only data this needs is a counter of requests with a status label. The function `rate()` turns the counter into a per-second value over a window, and `sum` joins the pods of the service. A recording rule in a PrometheusRule with the label `release: kps` stores each result as its own time series. The window of the playground is one hour. A production SLO uses a long window such as 30 days, with the same formula.

The burn rate is the error ratio divided by the error budget. A burn rate of `1` spends the budget exactly over the SLO window. A burn rate of `5` empties a 30-day budget in 6 days. An alert on one window is either too noisy or too slow. A multi-window alert joins a long window and a short window with `and`. The long window shows that the burn is not a spike, and the short window shows that it is still going on. The threshold is a burn rate, and `for:` adds a short wait. A selector that matches no status, such as `status=~"5xx"`, returns no data and the alert never fires, without any error.

Efficiency is the gap between requests and usage. A request is what the scheduler reserves. Usage is what the container consumes. metrics-server serves the latest usage through the Metrics API, and `kubectl top` shows it. cAdvisor, inside the kubelet, gives Prometheus the history in `container_cpu_usage_seconds_total` and `container_memory_working_set_bytes`. kube-state-metrics gives the requests in `kube_pod_container_resource_requests`. Dividing the request by the usage shows the gap. A ratio above `1` is waste and a ratio below `1` is a risk.

A request must cover the peak, not the average. The function `max_over_time()` gives the peak over a range, with a subquery for a rate. A good request sits a little above the peak, and a memory limit sits above the request. The fix is proven by running pods with the new values and no restarts, by a lower sum of requested resources and by ratios that are above `1` and close to it.

Key facts:

- `http_requests_total{status}` is a counter, and `status!~"5.."` selects the good requests. Prometheus anchors regular expressions at both ends.
- Burn rate is the error ratio divided by `1 - SLO`. Days until the budget is gone are the window in days divided by the burn rate.
- A PrometheusRule that Prometheus must select carries the label `release: kps` in this setup. A new rule reaches Prometheus after about a minute.
- `kubectl top` shows the latest usage from metrics-server. It is not a peak.
- Use `container_memory_working_set_bytes`, and use `container!=""` to drop the series for the whole pod.
- `kubectl set resources` changes requests and limits and starts a rollout. A memory limit must not be lower than the request.

<!-- astrona:playground:destroy -->

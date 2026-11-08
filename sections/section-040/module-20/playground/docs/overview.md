# Overview: Measure Service Levels And Resource Efficiency (Playground)

This playground gives you a cluster where one workload, `scout`, answers most requests and fails a few on purpose. It also gives you three workloads whose resource requests do not match what they use. You use it to measure a service level (an SLI, an SLO and an error budget), to alert on how fast the error budget burns, and to find and fix requests that are too high or too low. There is no grading.

## What's in the box

The cluster runs Kubernetes 1.35.8 and takes a few minutes to start.

| Where | Contents |
| --- | --- |
| `kube-system` | metrics-server 0.9.0, installed by the `metricsServer` addon of the `kind` runtime. It serves the Metrics API, so `kubectl top` works. It reads the kubelet every 15 seconds |
| `monitoring` | A trimmed kube-prometheus-stack 92.3.0: the Prometheus Operator, one Prometheus, kube-state-metrics and the kubelet scrape job (it reads cAdvisor). No Alertmanager, no Grafana, no node exporter. The Service `kps-prometheus` serves port `9090`. Prometheus scrapes every 15 seconds and keeps 6 hours of data. Alerts show in the Prometheus web interface and in `/api/v1/alerts` |
| `starfleet` | `scout` (two replicas of `podinfo` 6.15.0, requests `250m` CPU and `256Mi` memory), `probe` (one replica of `go-httpbin` 2.25.0, requests `1m` CPU and `4Mi` memory) and `shuttle` (a client pod that sends traffic in a loop) |

A ServiceMonitor with the label `release: kps` makes Prometheus scrape `scout`. The label is what the Prometheus resource selects. A PrometheusRule needs the same label.

The traffic loop in `shuttle` sends 19 normal requests and one request to `/status/500` to `scout` in every round. So about 5 percent of the requests to `scout` end with status `500`. It also sends 10 requests to `probe` in every round.

Leave the cluster running for at least 15 minutes before you work with long windows such as `[1h]`. Until then, a range query covers only the time since the start.

## Helpers

Use a second terminal for the port-forward and leave it running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

If port `9090` is in use on your machine, choose another local port, for example `19090:9090`, and use it in the commands. This helper runs a PromQL query and prints one line per result series:

```sh
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.endpoint, .instance, .job, .service, .namespace)), value: .value[1]}'
}
```

## Practice tasks

- Query `http_requests_total` and write the SLI of `scout` as the share of requests without a `5xx` status.
- Calculate the remaining error budget of a 99 percent SLO over one hour, and explain why it is negative.
- Write a PrometheusRule with a multi-window burn-rate alert and watch it go from `pending` to `firing`.
- Compare `kubectl top pods --containers` with the cAdvisor metrics in Prometheus.
- List the CPU and memory requests of every container with kube-state-metrics and divide them by the peak usage.
- Right-size `scout` (too high) and `probe` (too low), and prove with a query that the gap closed.
- Make `scout` return fewer errors by scaling it or changing the traffic, and watch the burn rate fall.

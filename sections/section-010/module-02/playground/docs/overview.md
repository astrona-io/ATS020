# Overview: Query Metrics With PromQL (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Prometheus already scraping two copies of a small web application while a client sends them steady traffic, some of it failing and some of it slow. There is no task, no `astrona submit` and no pass or fail. Write queries, change the traffic, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it. You also need `jq` on your machine.
- A trimmed Prometheus stack in `monitoring`: the Prometheus Operator and one Prometheus server (version 3.15.0, Service `kps-prometheus` on port `9090`), scraping every 15 seconds.

  | Namespace | Workload | What it is |
  | --- | --- | --- |
  | `starfleet` | `scout` | Two `podinfo` pods. Metrics: `http_requests_total` (counter, label `status`) and `http_request_duration_seconds` (histogram, labels `method`, `path`, `status`) |
  | `outpost` | `scout` | One `podinfo` pod with the same metrics |
  | `starfleet` | `shuttle` | A client running a traffic loop: one request per second to each `scout`, one `/status/500` every 5 seconds and one `/delay/1` every 10 seconds to the `starfleet` `scout` |

- Both `scout` workloads are already collected by ServiceMonitors. Give the playground five minutes after it starts before you run queries with `[5m]`.

## Helpers

Start a port-forward in a second terminal and leave it running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Then paste this once in each new terminal. `promql` runs an instant query and prints each series' labels and value:

```sh
promql() {
  curl -s http://127.0.0.1:9090/api/v1/query --data-urlencode "query=$1" |
    jq -r '.data.result[] | "\(.metric | del(.__name__) | to_entries | map("\(.key)=\(.value)") | join(","))\t\(.value[1])"'
}
```

Use it like this: `promql 'sum by (namespace) (rate(http_requests_total[5m]))'`. The query page is at `http://127.0.0.1:9090/query` while the port-forward runs.

## Practice tasks

- Write the error ratio of the `starfleet` `scout`, then the same ratio per pod with `sum by (pod)` on both sides. Predict what happens if only one side has `by (pod)`.
- Compare `rate(...[1m])` with `rate(...[5m])` for the `500` series and explain why one moves more.
- Find the 99th-percentile latency per path and compare it with the 50th. Which bucket bounds limit each answer?
- Scale the `outpost` `scout` to two replicas and check that `sum by (namespace)` stays about the same while the per-pod rates halve.
- Write a one-line check with `curl` and `jq -e` that passes only when the `outpost` error ratio is below 1%.

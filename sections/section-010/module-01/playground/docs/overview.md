# Overview: Scrape Workloads With ServiceMonitor And PodMonitor (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with a small Prometheus setup and a few workloads that serve metrics, and then waits. There is no task, no `astrona submit` and no pass or fail. Write monitors, break them, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` cluster running Kubernetes 1.35. `kubectl` is already pointed at it. You also need `jq` on your machine.
- A trimmed Prometheus stack in the namespace `monitoring`: the Prometheus Operator (Deployment `kps-operator`, version 0.94.1) and one Prometheus server (version 3.15.0, Service `kps-prometheus` on port `9090`). The Prometheus resource reads only ServiceMonitors and PodMonitors with the label `release: kps`, from every namespace. Alertmanager, Grafana and the node and Kubernetes object exporters are not installed.

  | Namespace | Workload | What it is |
  | --- | --- | --- |
  | `starfleet` | `scout` | Two `podinfo` pods serving metrics on `/metrics`, behind the Service `scout` (label `app: scout`, port named `http`, `9898`) |
  | `starfleet` | `shuttle` | A client pod with `curl` |
  | `outpost` | `scout` | One `podinfo` pod (label `app: scout`, container port named `http`) with no Service |

- No ServiceMonitor or PodMonitor for these workloads exists yet. At the start, Prometheus only scrapes itself and the operator.

## Helpers

Start a port-forward in a second terminal and leave it running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Then paste these once in each new terminal. `show_targets` prints each target's job, address, health and last error. `query_up` prints the `up` series, with an optional label filter.

```sh
show_targets() {
  curl -s http://127.0.0.1:9090/api/v1/targets |
    jq -r '.data.activeTargets[] | "\(.labels.job)\t\(.scrapeUrl)\t\(.health)\t\(.lastError)"'
}
query_up() {
  curl -s http://127.0.0.1:9090/api/v1/query --data-urlencode "query=up$1" |
    jq -r '.data.result[] | "\(.metric.job)\t\(.metric.pod)\t\(.value[1])"'
}
```

Use them like this: `show_targets`, `query_up '{namespace="starfleet"}'`. The Prometheus web page is at `http://127.0.0.1:9090` while the port-forward runs.

## Practice tasks

- Write a ServiceMonitor for `scout` without the `release: kps` label. Predict what `show_targets` shows after a minute, then add the label and time how long the target takes to appear.
- Scale `scout` in `starfleet` to three replicas and count the `up` series before and after.
- Collect the `outpost` pod with a PodMonitor, then compare the `job` label of its target with the ServiceMonitor's targets.
- Give a monitor a port name that does not exist and find the endpoints in the dropped targets (`/api/v1/targets?state=dropped`).
- Put the ServiceMonitor for the `starfleet` Service in the `monitoring` namespace instead, and make it work with `spec.namespaceSelector`.

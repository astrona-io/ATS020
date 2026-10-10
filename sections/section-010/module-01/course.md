# Scrape Workloads With ServiceMonitor And PodMonitor

A dashboard, an alert or a service level objective is only as good as the metrics behind it. Before any of those can work, Prometheus has to collect the workload's metrics, and on a Kubernetes platform that is not automatic. A new Deployment can expose a perfect `/metrics` endpoint and still never be collected, and nothing in `kubectl get` says so.

Prometheus is an open source monitoring system that collects numbers from programs over HTTP and stores them as time series. On Kubernetes it is usually run by the **Prometheus Operator**: a controller that runs Prometheus and turns a few custom resources into Prometheus configuration. Two of those resources decide what Prometheus collects. A **ServiceMonitor** points Prometheus at the endpoints behind a Service, and a **PodMonitor** points it at pods directly.

Keep one sentence in mind for this module: **Prometheus only scrapes what a monitor selects, and only reads monitors that its own selector selects.** Most "my metrics are missing" problems are one of those two selections failing.

The module has four parts. **Targets And The up Metric** shows what Prometheus collects, how to list its targets, and how the `up` metric reports each one. **Select A Service With A ServiceMonitor** writes a ServiceMonitor for `scout`, shows why the first version is ignored, and fixes it. **Scrape Pods Without A Service With A PodMonitor** collects a copy of `scout` that has no Service. **Finding A Missing Target** breaks a monitor in the two most common ways and reads where each mistake shows up.

## Learning objectives

After this module you can:

- Read the Prometheus targets list and the `up` metric to say which targets are scraped and which fail.
- Write a ServiceMonitor that selects a Service by label and scrapes a named port and path.
- Write a PodMonitor for pods that have no Service.
- Find why a new monitor produces no target: the Prometheus selector label, the namespace selector, the port name or the path.
- Prove a scrape works with `up == 1` for every endpoint of the workload.

## Before you start

You need Kubernetes basics: namespaces, Deployments, Services with named ports, labels and selectors, and the commands `kubectl get`, `kubectl apply`, `kubectl exec` and `kubectl port-forward`. You also need `jq` on your machine; the commands use it to pick fields out of the JSON that Prometheus returns.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It has a trimmed Prometheus stack in the namespace `monitoring`, installed from the `kube-prometheus-stack` Helm chart 92.3.0 with only two parts switched on: the Prometheus Operator (Deployment `kps-operator`) and one Prometheus server (pod `prometheus-kps-prometheus-0`, Service `kps-prometheus` on port `9090`). Alertmanager, Grafana and the exporters for nodes and Kubernetes objects are switched off to save memory. Prometheus runs version 3.15.0, and the operator runs version 0.94.1.

The Starfleet workloads run in two namespaces:

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | Two pods of `podinfo` 6.15.0, a small web application that serves its own metrics on `/metrics`. The Service `scout` has the label `app: scout` and the named port `http` (`9898`) |
| `starfleet` | `shuttle` | A client pod with `curl` |
| `outpost` | `scout` | One more `podinfo` pod with the label `app: scout`, and **no Service** |

No ServiceMonitor or PodMonitor exists for the Starfleet workloads yet, so at the start Prometheus only scrapes itself and the operator. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

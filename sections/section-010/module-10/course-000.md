# Scrape Workloads With ServiceMonitor And PodMonitor

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 4 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| Targets And The up Metric | Explore in the playground; apply this preparation in the following labs |
| Select A Service With A ServiceMonitor | Explore in the playground; apply this preparation in the following labs |
| Scrape Pods Without A Service With A PodMonitor | Scrape Pods With A PodMonitor |
| Finding A Missing Target | Repair ServiceMonitor Discovery |
| Scrape Pods With Raw Prometheus Configuration | Extend Raw Prometheus Pod Discovery |
| Scale A Workload From A Queue Metric | Scale From A Queue Metric |

## What you will prove

- Scrape Pods With A PodMonitor.
- Repair ServiceMonitor Discovery.
- Extend Raw Prometheus Pod Discovery.
- Scale From A Queue Metric.

## Before you start

You need Kubernetes basics: namespaces, Deployments, Services with named ports, labels and selectors, and the commands `kubectl get`, `kubectl apply`, `kubectl exec` and `kubectl port-forward`. You also need `jq` on your machine; the commands use it to pick fields out of the JSON that Prometheus returns.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It has a trimmed Prometheus stack in the namespace `monitoring`, installed from the `kube-prometheus-stack` Helm chart 93.3.0 with only two parts switched on: the Prometheus Operator (Deployment `kps-operator`) and one Prometheus server (pod `prometheus-kps-prometheus-0`, Service `kps-prometheus` on port `9090`). Alertmanager, Grafana and the exporters for nodes and Kubernetes objects are switched off to save memory. Prometheus runs version 3.15.0, and the operator runs version 0.94.1.

The Starfleet workloads run in two namespaces:

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | Two pods of `podinfo` 6.17.0, a small web application that serves its own metrics on `/metrics`. The Service `scout` has the label `app: scout` and the named port `http` (`9898`) |
| `starfleet` | `shuttle` | A client pod with `curl` |
| `outpost` | `scout` | One more `podinfo` pod with the label `app: scout`, and **no Service** |

No ServiceMonitor or PodMonitor exists for the Starfleet workloads yet, so at the start Prometheus only scrapes itself and the operator. The Operator examples run against the playground cluster, and `kubectl` already points at it. The raw configuration example pauses this playground and uses a separate lab with plain Prometheus and synthetic queue metrics.

Launch the playground for the reading exercises:

<!-- astrona:playground -->

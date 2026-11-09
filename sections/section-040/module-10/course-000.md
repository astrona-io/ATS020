# Measure Delivery With DORA Metrics

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 4 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| The Four DORA Metrics And Where The Data Lives | Explore in the playground; apply this preparation in the following labs |
| Deployment Frequency From The Sync Counter | Measure Deployment Frequency |
| Change Failure Rate From Application Health | Repair The Change Failure Rate Rule |
| Calculate Lead Time From Git Revisions | Calculate Lead Time From Git Revisions |
| Measure Time To Restore Service | Measure Time To Restore Service |

## What you will prove

- Measure Deployment Frequency.
- Repair The Change Failure Rate Rule.
- Calculate Lead Time From Git Revisions.
- Measure Time To Restore Service.

## Before you start

You need to read a Kubernetes Deployment and its status, use `kubectl port-forward`, and write a basic PromQL query with `rate()` or `increase()`. You also need `curl` and `jq` on your machine. You do not need to know Argo CD. The module explains the parts it uses.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. Setup takes several minutes, because the bootstrap makes ten real commits and waits for Argo CD to deploy each one. Two of the commits use an image tag that does not exist, on purpose.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `monitoring` | `prometheus-kps-prometheus` | One Prometheus (Prometheus Operator, kube-prometheus-stack 92.22.0). It scrapes every 15 seconds and keeps 6 hours of data. Alertmanager, Grafana, node exporter and kube-state-metrics are not installed |
| `argocd` | `argocd-application-controller` | Argo CD 3.6.1. The Application `scout` syncs automatically from a Git repository. A ServiceMonitor makes Prometheus scrape the controller |
| `gitea` | `gitea` | Gitea 28.3.0, a small Git server. It holds the repository `starfleet/starfleet-deploy` with the manifests of `scout` |
| `starfleet` | `scout`, `shuttle` | `scout` is created by Argo CD from the repository. `shuttle` is a client pod with `curl` |

The times and commit hashes in the output of this module come from one run. Your playground makes new ones, so your values differ.

Launch the playground for the reading exercises:

<!-- astrona:playground -->

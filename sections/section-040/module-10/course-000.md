# Measure Delivery With DORA Metrics

A platform team needs to know whether the platform helps teams ship software or slows them down. Opinions do not settle that question, but four numbers do. DevOps Research and Assessment (DORA) named them: deployment frequency, lead time for changes, change failure rate and time to restore service. Each number comes from data that the delivery tools already keep.

In this module the delivery tool is Argo CD, a GitOps controller. It watches a Git repository and applies every new commit to the cluster. Argo CD keeps a history of each deployment and exposes counters and gauges as Prometheus metrics. One of the four numbers is easy to read from those metrics. Another cannot be read from the obvious metric at all, and the module shows why. The exam expects you to pick the right data source for each number and to prove the result with a query.

The module has four parts. **The Four DORA Metrics And Where The Data Lives** defines each metric and finds its raw data in Git, in the Argo CD Application and in the metrics endpoint. **Deployment Frequency From The Sync Counter** counts deployments with `increase()` and stores the result as a recording rule. **Change Failure Rate From Application Health** shows why a failed sync is not the signal, computes the rate from health and ends with a graded lab. **Lead Time And Time To Restore From Timestamps** calculates the two time-based metrics from commit times and deployment times.

## Learning objectives

After this module you can:

- Define deployment frequency, lead time for changes, change failure rate and time to restore service.
- Count deployments over a time window from the Argo CD sync counter in Prometheus.
- Calculate the change failure rate from the Application health, and explain why the sync phase does not show a failed change.
- Calculate lead time from a commit time in Git and the deployment time recorded by Argo CD.
- Calculate time to restore service from a bad deployment and the next healthy one.
- Name one change to the delivery process that improves each metric.

## Before you start

You need to read a Kubernetes Deployment and its status, use `kubectl port-forward`, and write a basic PromQL query with `rate()` or `increase()`. You also need `curl` and `jq` on your machine. You do not need to know Argo CD. The module explains the parts it uses.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. Setup takes several minutes, because the bootstrap makes ten real commits and waits for Argo CD to deploy each one. Two of the commits use an image tag that does not exist, on purpose.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `monitoring` | `prometheus-kps-prometheus` | One Prometheus (Prometheus Operator, kube-prometheus-stack 92.22.0). It scrapes every 15 seconds and keeps 6 hours of data. Alertmanager, Grafana, node exporter and kube-state-metrics are not installed |
| `argocd` | `argocd-application-controller` | Argo CD 3.6.1. The Application `scout` syncs automatically from a Git repository. A ServiceMonitor makes Prometheus scrape the controller |
| `gitea` | `gitea` | Gitea 28.1.0, a small Git server. It holds the repository `starfleet/starfleet-deploy` with the manifests of `scout` |
| `starfleet` | `scout`, `shuttle` | `scout` is created by Argo CD from the repository. `shuttle` is a client pod with `curl` |

The times and commit hashes in the output of this module come from one run. Your playground makes new ones, so your values differ.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

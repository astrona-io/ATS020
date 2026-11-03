# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to write a PrometheusRule with recording rules and an alerting rule, how `increase()`, `rate()` and `changes()` work, how an SLO and an error budget relate to an error ratio, and how to read requests and usage of a container. You need to know how to change the requests of a Deployment with `kubectl set resources`.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs Argo CD, Gitea, metrics-server and a trimmed kube-prometheus-stack, and it replays ten backdated deployments. Allow about ten minutes for the first start.

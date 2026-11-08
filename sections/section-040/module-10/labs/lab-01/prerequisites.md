# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to read and edit a Kubernetes resource with `kubectl`, run a PromQL query with `increase()` and `changes()`, and read a PrometheusRule. You also need to know what an Argo CD Application is and what its sync phase and health status mean.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs Prometheus, Gitea and Argo CD, then makes ten real deployments. Allow about ten minutes for the first start.

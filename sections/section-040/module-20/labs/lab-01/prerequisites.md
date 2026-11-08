# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to read and edit a Kubernetes resource with `kubectl`, run a PromQL query with `rate()` and `sum`, and read a PrometheusRule. You also need to know what an SLI, an SLO and a burn rate are.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs Prometheus and kube-state-metrics and starts a traffic loop. Allow about five minutes for the first start. Prometheus needs about ten minutes of traffic before the one-hour window holds enough data.

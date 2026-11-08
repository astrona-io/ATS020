# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to read and edit a Kubernetes resource with `kubectl`. You also need to know PromQL: `rate()` on a counter, `sum by (...)`, the error ratio, and `histogram_quantile()` on a histogram. You need to know how to query Prometheus with `curl` and `jq`.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs the Prometheus Operator and one Prometheus, and it starts a pod that sends traffic. Allow about five minutes for the first start. The `[5m]` window fills with data during the first minutes.

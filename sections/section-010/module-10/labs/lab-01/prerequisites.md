# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to read and edit a Kubernetes resource with `kubectl`. You also need to know what a ServiceMonitor is, which label the Prometheus resource selects, and how to read the targets and the dropped targets in Prometheus.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs the Prometheus Operator and one Prometheus. Allow about five minutes for the first start.

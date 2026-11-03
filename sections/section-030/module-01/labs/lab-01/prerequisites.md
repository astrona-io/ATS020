# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to read a Kubernetes Service and its ports, read pod logs with `kubectl logs`, and send a request from a pod with `kubectl exec`. You need to know the main parts of an OpenTelemetry Collector: receivers, processors, exporters and pipelines.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs cert-manager and the OpenTelemetry Operator, so allow a few minutes for the first start.

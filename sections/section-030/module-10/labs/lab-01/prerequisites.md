# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to read a Kubernetes Service and its ports, read pod logs with `kubectl logs`, and send a request from a pod with `kubectl exec`. You need to know the main parts of an OpenTelemetry Collector: receivers, processors, exporters and pipelines.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs cert-manager and the OpenTelemetry Operator, so allow a few minutes for the first start.

The lab opens two ports on your machine, on `127.0.0.1` only: `26686` for the Jaeger UI and `28888` for the Collector's metrics. They are not the usual ports (`16686` and `8888`), so a Jaeger or Collector already running on your machine does not block them. Keep `26686` and `28888` free before you start.

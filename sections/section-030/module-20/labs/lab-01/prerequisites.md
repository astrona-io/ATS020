# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know what an annotation is, how a Deployment creates pods from its pod template, and how to read pod logs with `kubectl logs`. You need to know what a trace and a span are, and what the OpenTelemetry Operator and its Instrumentation resource do.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs cert-manager and the OpenTelemetry Operator, so allow a few minutes for the first start.

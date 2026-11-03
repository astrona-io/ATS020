# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to write an OpenTelemetryCollector with an OTLP receiver and an exporter to Jaeger, what an Instrumentation resource and the inject annotation do, and why the annotation belongs on the pod template. You need to know what a trace and a span are, how the `traceparent` header joins two services into one trace, and how to read a trace in the Jaeger API.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs cert-manager and the OpenTelemetry Operator, so allow a few minutes for the first start.

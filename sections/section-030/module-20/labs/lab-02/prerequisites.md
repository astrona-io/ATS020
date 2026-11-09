# Prerequisites

You need `astrona`, `kubectl`, `curl`, `jq`, and `python3` on your machine. Python is used by the grader and automated reference solution.

You should be able to query Jaeger, follow trace and parent span identifiers, and calculate elapsed time from span timestamps. You should understand the difference between a service waiting for a downstream request and the downstream operation doing the delayed work.

The lab starts a single-node `kind` cluster with Kubernetes 1.35, cert-manager, and the OpenTelemetry Operator. Allow a few minutes for startup and for spans from both services to arrive.

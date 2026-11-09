# Prerequisites

You need `astrona`, `kubectl`, `curl`, `jq`, and `python3`. Python is used by the graders.

You should know how to compare trace and parent span identifiers, inspect injected environment variables, and restart a Deployment.

The lab creates its own single-node `kind` cluster. It does not require another lab to be completed or running. Allow a few minutes for cert-manager, the OpenTelemetry Operator, and the workloads to start.

# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `openssl`.

You need to know how an admission webhook works: the API server calls a Service, and a `ValidatingWebhookConfiguration` sets the `failurePolicy`. You need to read a Service selector, an EndpointSlice and a Secret. You need to know what a serving certificate, a certificate authority (CA) and a subject alternative name (SAN) are. You need to know what a Deployment scaled to zero looks like and how a Prometheus target reports `up`.

The lab starts a single-node `kind` cluster with Kubernetes 1.35 and a small Prometheus stack. Allow a few minutes for the first start.

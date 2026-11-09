# Add Tracing Without Code Changes Using Auto-Instrumentation

A trace is only useful when it covers every service that a request touches. Adding a tracing library to each service means changing code, rebuilding images and rolling out every service again. The OpenTelemetry Operator offers another way: it adds a tracing agent to a pod when the pod is created, and the application code stays as it is. The exam expects you to set this up by hand and to find out why it does not work.

The setting has two parts, an Instrumentation resource and an annotation on the pod template. Both are small, and a mistake in either one gives no error. The pod starts, serves requests and has no agent. The only sign is a trace in Jaeger that is missing a service or that breaks in two.

The module has three parts. **What The Operator Injects Into A Pod** creates the Instrumentation and the annotation for `relay` and reads the init container and the environment variables that the Operator adds. **Reading One Trace Across Two Services** finds a trace with spans from `relay` and `scout`, names the slowest step, and shows what happens when the propagators change. **Finding Why A Pod Is Not Instrumented** breaks the setup in two ways, reads the Operator log, and ends with a graded lab.

## Learning objectives

After this module you can:

- Write an Instrumentation resource with the exporter endpoint, the propagators and the sampler.
- Annotate the pod template of a Deployment so the Operator injects the Node.js agent, and restart it so the change takes effect.
- Read the injected init container and the environment variables to prove that injection happened.
- Follow one request across two services in Jaeger and name the slowest span.
- Find why a pod was not instrumented: the annotation on the wrong object, an Instrumentation in another namespace, or a pod that was not created again.

## Before you start

You need to know what a trace and a span are, how a Deployment creates pods from its pod template, and how to use `kubectl port-forward`, `kubectl logs` and `jq`. You need to read an annotation and a custom resource.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. cert-manager 1.21.3 and the OpenTelemetry Operator 0.160.0 are installed and ready. A working Collector (contrib image 0.162.0) sends spans to Jaeger 2.22.0. No Prometheus stack runs, to save memory.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `observability` | `jaeger` | Jaeger 2.22.0 in one pod with in-memory storage. The web interface and the API are on port `16686` |
| `observability` | `otel` | The Collector. The Service `otel-collector` takes OTLP on ports `4317` (gRPC) and `4318` (HTTP) and exports to Jaeger |
| `starfleet` | `scout` | One pod of `podinfo` 6.15.0 with its own OpenTelemetry tracing on, sending to `otel-collector.observability:4317` |
| `starfleet` | `relay` | A small Node.js HTTP server (`node:22-alpine`) with no tracing code. Each request makes one request to `scout`. The path `/slow` asks `scout` for `/delay/1` |
| `starfleet` | `shuttle` | A client pod that sends a request to `relay` every 2 seconds, and a slow one every fifth round |

No Instrumentation exists yet, and `relay` has no annotation. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

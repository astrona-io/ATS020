# Add Tracing Without Code Changes Using Auto-Instrumentation

The `relay` service forwards requests to `scout`, but only `scout` records spans. Jaeger can show the work inside `scout`; it cannot show how long `relay` spent handling the request. You will add tracing to `relay` through the OpenTelemetry Operator, without editing its Node.js application code.

**Auto-instrumentation** uses an agent to record operations in supported application libraries. The Operator injects that agent when a pod is created. An `Instrumentation` resource supplies its settings, and a pod-template annotation requests injection.

Start by creating those settings and inspecting the new pod. Then read a trace across both services and identify the operation responsible for a slow request. A separate exercise removes and restores context propagation, followed by troubleshooting missing injection. Each lesson has a short graded lab with four tasks. The labs start independently: enable injection, investigate a slow trace, restore propagation, and repair missing injection. Allow 10–15 minutes of task work per lab, plus cluster startup and span export time.

## Learning objectives

After this module, you will be able to:

- Configure an `Instrumentation` resource with a Collector endpoint, propagators, and sampler.
- Request Node.js agent injection through a Deployment's pod template and verify the resulting init container and environment variables.
- Find a trace that links two services through parent and child spans.
- Use span timings to locate a slow operation and save trace evidence.
- Distinguish missing instrumentation from broken context propagation.
- Repair misplaced annotations, incorrect resource references, and pods that still use old settings.

## Before you start

You should know how Deployments create pods, how to read Kubernetes annotations, and how to use `kubectl logs` and `kubectl port-forward`. You will also use `curl` and `jq` to read Jaeger's application programming interface (API).

The playground runs a single-node `kind` cluster with Kubernetes 1.35.8, cert-manager 1.21.3, and the OpenTelemetry Operator 0.162.0. A working Collector uses the contrib image 0.165.0 and exports to Jaeger 2.23.0. There is no Prometheus stack.

| Namespace | Workload | Starting state |
| --- | --- | --- |
| `observability` | `jaeger` | In-memory trace storage; web interface and API on port `16686` |
| `observability` | `otel` | Collector accepting OpenTelemetry Protocol (OTLP) on ports `4317` and `4318` |
| `starfleet` | `scout` | `podinfo` 6.17.0 with tracing enabled, exporting to the Collector on port `4317` |
| `starfleet` | `relay` | A `node:22-alpine` application with no tracing code; forwards requests to `scout` |
| `starfleet` | `shuttle` | Sends a request to `relay` every two seconds and an additional `/slow` request every fifth round |

`relay` forwards `/slow` to `scout`'s `/delay/1` route, which waits about one second. No `Instrumentation` resource or injection annotation exists yet. The playground sets the `kubectl` context for the exercises.

<!-- astrona:playground -->

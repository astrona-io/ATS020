# Question

Solve this question on: `terminal`

Requests to the service `relay` in the namespace `starfleet` are slow sometimes, and nobody can say where the time goes. `relay` is a Node.js program with no tracing code. Every request to `relay` makes one request to the service `scout` in `starfleet`, and a request to `relay` on the path `/slow` makes `scout` wait about one second. The pod `shuttle` sends such requests all the time.

The platform team wants distributed tracing. Jaeger already runs in the namespace `observability` as the Service `jaeger`, with OTLP (OpenTelemetry Protocol) on ports `4317` and `4318` and the web interface and API on `16686`. The OpenTelemetry Operator and cert-manager are installed. `scout` creates its own spans and sends them to `http://otel-collector.observability`, but no Collector exists, and the traffic never reached Jaeger.

## Task

1. Create an OpenTelemetryCollector named `otel` in the namespace `observability`, in `deployment` mode. It receives OTLP on ports `4317` and `4318`, batches the spans and exports them to Jaeger.
2. `scout` sends its spans to the wrong port. Find out why they do not arrive and fix the exporter endpoint of `scout`. It must use OTLP over gRPC.
3. Instrument `relay` without a code change. Create an Instrumentation for Node.js, annotate `relay` so that the Operator injects the agent, and make sure the trace context travels from `relay` to `scout`.
4. Open a slow trace in Jaeger and find the span that holds the time. Record the answer in a ConfigMap named `slow-call` in the namespace `starfleet`, with the key `service` (the service that owns the slowest span) and the key `operation` (the name of that span, spelled exactly as Jaeger shows it).

## Constraints

- Keep the Deployment `relay` with its image `node:22-alpine`, its command and the ConfigMap `relay-app`. Do not add tracing code to the script.
- Keep `scout` as it is, except for the exporter endpoint. Do not inject an agent into it.
- The agent of `relay` must send its spans to the Collector, not straight to Jaeger. The Collector must export to Jaeger, not only to a `debug` exporter.
- Keep the Collector in `deployment` mode, named `otel`, so that its Service is `otel-collector`.

## How the answer is checked

The grader runs five checks. The first reads the Collector and its own counters, and needs spans accepted and sent. The second checks that the running `relay` pod has the inject annotation, the init container that the Operator adds, the `tracecontext` propagator and an exporter endpoint at the Collector. The third reads the Jaeger API and needs a recent trace in which a span of `scout` is a child of a span of `relay`. The fourth reads your ConfigMap `slow-call` and compares it with the slowest span in Jaeger. The fifth checks that `relay`, `scout` and the Collector keep their design. Telemetry arrives late, so the grader retries for a few minutes.

Hint: the Operator changes a pod only when the pod is created, and the agent and the Collector batch spans, so give a fix about a minute before you look in Jaeger. Reach Jaeger with `kubectl -n observability port-forward svc/jaeger 16686:16686`.

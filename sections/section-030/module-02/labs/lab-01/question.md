# Question

Solve this question on: `terminal`

The `scout` service in the `starfleet` namespace creates its own spans and sends them through the Collector `otel` to Jaeger. The `relay` service in front of it is a plain Node.js program with no tracing code. Every request to `relay` makes one request to `scout`. The `shuttle` pod sends such requests all the time.

The team wants `relay` traced without any code change, using the OpenTelemetry Operator. Someone set it up, but Jaeger shows no span from `relay`, and the spans of `scout` still start new traces. The `relay` pod is `Running` and serves requests.

## Task

1. Find out why the Operator does not instrument `relay`, and why a trace would not contain both services even if it did.
2. Fix the setup so that the Operator injects the Node.js agent into a new `relay` pod and the agent sends the trace context to `scout`.
3. Prove the fix. Jaeger must hold a trace with a span from `relay` and a span from `scout`, and the span of `scout` must have a span of `relay` as its parent.

## Constraints

- Keep the Deployment `relay` in `starfleet`, with its image `node:22-alpine`, its command and the ConfigMap `relay-app`. Do not add tracing code to the script.
- Do not change `scout`. It must keep sending to `http://otel-collector.observability:4317`.
- Keep the Collector `otel` as it is. The agent of `relay` must send its spans to the Collector, not straight to Jaeger.
- Do not use the `debug` exporter and do not delete the Deployment `relay`.

## How the answer is checked

The grader runs three checks. The first checks that the running `relay` pod has the inject annotation, the init container that the Operator adds, the `tracecontext` propagator and an exporter endpoint at the Collector. The second checks that `relay`, `scout` and the Collector are unchanged in design. The third reads the Jaeger API and needs a recent trace in which a span of `scout` is a child of a span of `relay`. Telemetry arrives late, so the grader retries for a few minutes.

Hint: the Operator changes a pod only when the pod is created. After you fix the resources, make the Deployment create a new pod, and give the traffic about a minute to arrive in Jaeger.

# Question

Solve this question on: `terminal`

The `scout` service in the `starfleet` namespace is instrumented with OpenTelemetry. It sends its spans over OTLP (OpenTelemetry Protocol) to the Service `otel-collector` in the `observability` namespace, on port `4317`. That Service belongs to the OpenTelemetryCollector `otel`, which the OpenTelemetry Operator runs. The Collector must forward the spans to Jaeger, the trace backend, which runs in the same namespace as the Service `jaeger`.

The operations team reports that no trace of `scout` shows up in Jaeger. The pod of the Collector is `Running`, so the fault is in its configuration.

## Task

1. Find out why spans from `scout` do not reach Jaeger. Use the Collector log, the Services in `observability` and the Collector's own metrics on port `8888`.
2. Fix the OpenTelemetryCollector `otel` so that the spans of `scout` arrive in Jaeger through the Collector.
3. Prove the fix. The two counters `otelcol_receiver_accepted_spans` and `otelcol_exporter_sent_spans` must be above `0`, and the Jaeger API must list `scout` as a service.

## Constraints

- Keep the Collector named `otel`, in the `observability` namespace, in `deployment` mode.
- Keep the Service name `otel-collector` and port `4317`.
- Do not change `scout`. It must keep sending to `http://otel-collector.observability:4317`.
- Do not delete the Collector and do not replace its exporter with a `debug` exporter.

## How the answer is checked

The grader runs three checks. The first checks that the Collector, its Service and the `scout` endpoint are unchanged in design. The second reads the Collector's counters and needs spans accepted and sent. The third reads the Jaeger API and needs recent spans from the service `scout`. Telemetry arrives late, so the grader retries for a few minutes.

Hint: after you change the Collector, the Operator replaces the pod. Wait about 40 seconds before you look at the log again.

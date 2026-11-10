# Question

Solve this question on: `terminal`

Spans from `scout` in the `starfleet` namespace do not reach Jaeger. `scout` sends them to the OpenTelemetryCollector `otel` in the `observability` namespace, through the Service `otel-collector` on port `4317`. The Collector pod is `Running`.

## Task

Fix the OpenTelemetryCollector `otel` so that the spans of `scout` reach the Service `jaeger` in `observability`.

The fix is done when:

- the Collector's counters `otelcol_receiver_accepted_spans` and `otelcol_exporter_sent_spans` on port `8888` are above `0`
- Jaeger lists `scout` as a service

## Constraints

- Change only the OpenTelemetryCollector `otel`. Keep its name, its namespace, `deployment` mode and the Service `otel-collector` on port `4317`.
- Do not change `scout`, and do not replace the exporter with a `debug` exporter.

# Question

Solve this question on: `terminal`

Spans from `scout` in the `starfleet` namespace do not reach Jaeger. `scout` sends them to the OpenTelemetryCollector `otel` in the `observability` namespace, through the Service `otel-collector` on port `4317`. The Collector pod is `Running`.

## Tasks

1. Fix the exporter of the OpenTelemetryCollector `otel` so that it connects to the Service `jaeger` in `observability`.
2. Make the exporter deliver spans: the counters `otelcol_receiver_accepted_spans` and `otelcol_exporter_sent_spans` on port `8888` are both above `0`.
3. Prove that Jaeger lists `scout` as a service.

## Constraints

- Change only the OpenTelemetryCollector `otel`. Keep its name, its namespace, `deployment` mode and the Service `otel-collector` on port `4317`.
- Do not change `scout`, and do not replace the exporter with a `debug` exporter.

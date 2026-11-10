# Question

Solve this question on: `terminal`

The Deployment `probe` in the `outpost` namespace sends one HTTP request every 2 seconds and should report each request as a span to Jaeger. Jaeger runs in the `tracing` namespace. Its Service `jaeger` receives OpenTelemetry Protocol (OTLP) over HTTP on port `4318` and serves the web interface and query API on port `16686`. Jaeger does not list `probe` yet.

## Tasks

1. Switch OpenTelemetry on in `probe`: set its environment variable `OTEL_ENABLED` to `true`.
2. Set the environment variable `OTEL_EXPORTER_OTLP_ENDPOINT` of `probe` to the OTLP/HTTP address of the Service `jaeger` in `tracing`. Wait until the new pod is ready.
3. The spans of `probe` carry an `exception` span event. Read them from `GET /api/v3/traces` and save the events to `/tmp/ats-020-exception.json`, as a JSON array of the event objects exactly as the API returns them under `spans[].events[]`.

## Constraints

- Change only `OTEL_ENABLED` and `OTEL_EXPORTER_OTLP_ENDPOINT`. Keep `TRACE_SERVICE` and `TARGET_URL` as they are: the failing request is the source of the exception.
- Keep `probe` in `outpost` with one replica, and do not restart Jaeger. It keeps traces only in memory.

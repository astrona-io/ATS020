# Question

Solve this question on: `terminal`

The Deployment `probe` in the `outpost` namespace sends one HTTP request every 2 seconds and should report each request as a span to Jaeger. Jaeger runs in the `tracing` namespace. Its Service `jaeger` receives OpenTelemetry Protocol (OTLP) over HTTP on port `4318` and serves the web interface and query API on port `16686`. Jaeger does not list `probe` yet.

## Tasks

1. Switch OpenTelemetry on in `probe`: set its environment variable `OTEL_ENABLED` to `true`.
2. Set the environment variable `OTEL_EXPORTER_OTLP_ENDPOINT` of `probe` to the OTLP/HTTP address of the Service `jaeger` in `tracing`. Wait until the new pod is ready.
3. Each span of `probe` has a span event named `exception`. Read the spans from the Jaeger query API:

   ```text
   http://127.0.0.1:26686/api/v3/traces?query.service_name=probe&query.start_time_min=<START>&query.start_time_max=<END>
   ```

   `<START>` and `<END>` are times in RFC 3339 format around the last few minutes, for example `2026-11-11T10:00:00Z`. Save every event named `exception` from the `events` list of the spans, unchanged, as one JSON array in `/tmp/ats-020-exception.json`.

## Constraints

- Change only `OTEL_ENABLED` and `OTEL_EXPORTER_OTLP_ENDPOINT`. Keep `TRACE_SERVICE` and `TARGET_URL` as they are: the failing request is the source of the exception.
- Keep `probe` in `outpost` with one replica, and do not restart Jaeger. It keeps traces only in memory.

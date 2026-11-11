# Question

Solve this question on: `terminal`

The Deployment `probe` in the `outpost` namespace sends one HTTP request every 2 seconds and should report each request as a span to Jaeger. Jaeger runs in the `tracing` namespace. Its Service `jaeger` receives OpenTelemetry Protocol (OTLP) over HTTP on port `4318` and serves the web interface and query API on port `16686`. Jaeger does not list `probe` yet.

## Tasks

1. Switch OpenTelemetry on in `probe`: set its environment variable `OTEL_ENABLED` to `true`.
2. Set the environment variable `OTEL_EXPORTER_OTLP_ENDPOINT` of `probe` to the OTLP/HTTP address of the Service `jaeger` in `tracing`. Wait until the new pod is ready.
3. Each span of `probe` has a span event named `exception`. Read the spans of `probe` from the Jaeger query API, and save these events to `/tmp/ats-020-exception.json`:
   - The lab forwards port `16686` of the Service `jaeger` to your terminal, so the endpoint is `GET http://127.0.0.1:26686/api/v3/traces`. It needs three query parameters: `query.service_name=probe`, `query.start_time_min` and `query.start_time_max`. The two times are in RFC 3339 format, for example `2026-11-11T10:00:00Z`, and must cover the last few minutes.
   - The file is one JSON array. Each item is one whole event object from `result.resourceSpans[].scopeSpans[].spans[].events[]` whose `name` is `exception`.
   - Keep each object exactly as the API returns it, with its `attributes` `exception.type`, `exception.message` and `exception.stacktrace`. Do not save only the span `status` or a single attribute.

## Constraints

- Change only `OTEL_ENABLED` and `OTEL_EXPORTER_OTLP_ENDPOINT`. Keep `TRACE_SERVICE` and `TARGET_URL` as they are: the failing request is the source of the exception.
- Keep `probe` in `outpost` with one replica, and do not restart Jaeger. It keeps traces only in memory.

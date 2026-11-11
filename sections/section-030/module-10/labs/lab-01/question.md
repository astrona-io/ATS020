# Question

Solve this question on: `terminal`

The Deployment `probe` in the `outpost` namespace sends one HTTP request every 2 seconds and should report each request as a span to Jaeger. Jaeger runs in the `tracing` namespace. Its Service `jaeger` receives OpenTelemetry Protocol (OTLP) over HTTP on port `4318` and serves the web interface and query API on port `16686`. Jaeger does not list `probe` yet.

## Tasks

1. Switch OpenTelemetry on in `probe`: set its environment variable `OTEL_ENABLED` to `true`.
2. Set the environment variable `OTEL_EXPORTER_OTLP_ENDPOINT` of `probe` to the OTLP/HTTP address of the Service `jaeger` in `tracing`. Wait until the new pod is ready.
3. Take one trace ID of `probe` from its log, and save the `exception` event of that trace from `http://host.docker.internal:26686` to `/workspace/ats-020-exception.json` as a JSON object.

## Constraints

- Change only the Deployment `probe` in `outpost`. Do not change, restart or delete anything else.

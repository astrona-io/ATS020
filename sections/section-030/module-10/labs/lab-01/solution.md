# Solution

The Deployment `probe` in `outpost` sends no spans to Jaeger for two reasons. `OTEL_ENABLED` is `false`, so the program creates no spans. `OTEL_EXPORTER_OTLP_ENDPOINT` points at `jaeger.observability`, but Jaeger runs in the namespace `tracing`.

## Tasks 1 and 2: fix the two environment variables

Set both variables with one command. The endpoint is the Service `jaeger` in `tracing` on port `4318`, the port for OTLP (OpenTelemetry Protocol) over HTTP. The Deployment controller then replaces the pod:

```sh
kubectl -n outpost set env deployment/probe OTEL_ENABLED=true OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger.tracing:4318
kubectl -n outpost rollout status deployment/probe --timeout=180s
kubectl -n outpost logs deploy/probe --tail=3
```

```text
Span sent: trace_id=a0731d01872898237c3e8d5342090b92
Span sent: trace_id=dc683467134689431d087234569a7783
Span sent: trace_id=145f52dfc694bf640f78814c8caa9f75
```

The output is shortened to the log lines. Each `Span sent` line means one span reached Jaeger, and the part after `trace_id=` is a full trace ID. Your trace IDs differ.

## Task 3: save the exception event

Copy one trace ID from the log and ask the Jaeger query API for that trace. `jq` walks every object in the response (`..`) and keeps only the one named `exception`. This example uses the trace ID `a4e1c900c778f5bb80e91337a17149fe`; use your own:

```sh
curl -s http://host.docker.internal:26686/api/v3/traces/a4e1c900c778f5bb80e91337a17149fe | jq '.. | objects | select(.name? == "exception")' > /workspace/ats-020-exception.json
cat /workspace/ats-020-exception.json
```

The output is shortened: the attributes `exception.message` and `exception.stacktrace` are cut.

```json
{
  "timeUnixNano": "1794425125395461388",
  "name": "exception",
  "attributes": [
    {
      "key": "exception.type",
      "value": {
        "stringValue": "URLError"
      }
    }
  ]
}
```

The file must start with `"timeUnixNano"` and `"name": "exception"`. If `jq` fails with `Invalid numeric literal`, check that the path is `/api/v3/traces/`, with an `s`.
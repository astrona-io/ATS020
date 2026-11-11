#!/usr/bin/env bash
# Applies the reference solution. Run by `astrona test` only. It switches
# tracing on, points probe at the Service jaeger in tracing, waits until Jaeger
# holds a probe span with an exception event, and exports one such event. It
# reads the API through the API server proxy so that it needs no port-forward.
set -euo pipefail
api=/api/v1/namespaces/tracing/services/jaeger:16686/proxy/api/v3/traces
window='query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2100-01-01T00:00:00Z'
export_file=/tmp/ats-020-exception.json

kubectl -n outpost set env deployment/probe OTEL_ENABLED=true OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger.tracing:4318
kubectl -n outpost rollout status deployment/probe --timeout=180s

for attempt in $(seq 1 36); do
  kubectl get --raw "$api?$window&query.serviceName=probe&query.searchDepth=20" 2>/dev/null |
    jq -s '[.[].result.resourceSpans[]?.scopeSpans[]?.spans[]?.events[]? | select(.name == "exception")] | first' >"$export_file" || true
  jq -e '.name == "exception"' "$export_file" >/dev/null 2>&1 && break
  sleep 5
done
jq -e '.name == "exception"' "$export_file" >/dev/null || { echo "[solution] Jaeger returned no exception event for probe" >&2; exit 1; }
echo "[solution] Exported one exception event to $export_file."

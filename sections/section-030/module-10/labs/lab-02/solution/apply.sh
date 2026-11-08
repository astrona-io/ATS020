#!/usr/bin/env bash
# Applies the reference solution. Run by `astrona test` only. It takes both
# service names from Jaeger, as the task asks, and reads the API through the
# API server proxy so that it needs no port-forward.
set -euo pipefail
api=/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces
window='query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2100-01-01T00:00:00Z'
export_file=/tmp/ats-020-incident-traces.json

service_with_tag() {
  # The value is already URL-encoded: {"incident.code":"<code>"}
  kubectl get --raw "$api?$window&query.searchDepth=20&query.attributes=%7B%22incident.code%22%3A%22$1%22%7D" |
    jq -er '[.result.resourceSpans[].resource.attributes[] | select(.key == "service.name") | .value.stringValue] | unique | if length == 1 then .[0] else error("expected one service") end'
}

delayed_service="$(service_with_tag retry-storm)"
pressured_service="$(service_with_tag queue-pressure)"

kubectl -n starfleet set env "deployment/$delayed_service" RESPONSE_DELAY_MS=20
kubectl -n starfleet rollout status "deployment/$delayed_service" --timeout=180s
kubectl -n starfleet scale "deployment/$pressured_service" --replicas=3
kubectl -n starfleet rollout status "deployment/$pressured_service" --timeout=180s

for attempt in $(seq 1 36); do
  if response="$(kubectl get --raw "$api?$window&query.serviceName=$delayed_service&query.searchDepth=5" 2>/dev/null)" &&
    jq -e '[.result.resourceSpans[].scopeSpans[].spans[].traceId] | unique | length == 5' <<<"$response" >/dev/null 2>&1; then
    printf '%s\n' "$response" >"$export_file"
    echo "[solution] Exported five traces of $delayed_service to $export_file."
    exit 0
  fi
  sleep 5
done
echo '[solution] Jaeger did not return five traces in time' >&2
exit 1

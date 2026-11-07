#!/usr/bin/env bash
# Applies the reference solution. Run by `astrona test` only. It finds the
# failing service in Jaeger, as the task asks, exports the exception events of
# its spans, and repairs the address the Deployment calls. It reads the API
# through the API server proxy so that it needs no port-forward.
set -euo pipefail
api=/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces
window='query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2100-01-01T00:00:00Z'
service_file=/tmp/ats-020-error-service.txt
export_file=/tmp/ats-020-exceptions.json
# The error status is 2 in OTLP JSON; a server may also spell it STATUS_CODE_ERROR.
errored='(.status.code // 0) as $code | ($code == 2 or $code == "STATUS_CODE_ERROR")'

failing_services=()
for service in $(kubectl get --raw "${api%/traces}/services" | jq -r '.services[]'); do
  if kubectl get --raw "$api?$window&query.serviceName=$service&query.searchDepth=20" 2>/dev/null |
    jq -e "[.result.resourceSpans[]?.scopeSpans[]?.spans[]? | select($errored)] | length >= 1" >/dev/null; then
    failing_services+=("$service")
  fi
done
[ "${#failing_services[@]}" -eq 1 ] || { echo "[solution] expected one service with error spans, found: ${failing_services[*]:-none}" >&2; exit 1; }
failing_service="${failing_services[0]}"
printf '%s\n' "$failing_service" >"$service_file"
echo "[solution] The service with error spans is $failing_service."

kubectl get --raw "$api?$window&query.serviceName=$failing_service&query.searchDepth=20" |
  jq "[.result.resourceSpans[].scopeSpans[].spans[] | select($errored) | .events[]? | select(.name == \"exception\")]" >"$export_file"
jq -e 'length >= 1' "$export_file" >/dev/null || { echo "[solution] no exception events found to export" >&2; exit 1; }
echo "[solution] Exported $(jq length "$export_file") exception events to $export_file."

kubectl -n starfleet set env "deployment/$failing_service" TARGET_URL=http://shuttle.starfleet:8080
kubectl -n starfleet rollout status "deployment/$failing_service" --timeout=180s

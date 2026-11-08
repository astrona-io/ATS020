#!/usr/bin/env bash
# Helper for `astrona test`: wait until Jaeger holds a probe trace whose span
# carries an exception event, so the reference solution has something to
# export. Each workload sends a trace every few seconds, and Jaeger batches
# spans before it stores them.
set -uo pipefail
api=/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces
window='query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2100-01-01T00:00:00Z'
for attempt in $(seq 1 36); do
  response="$(kubectl get --raw "$api?$window&query.serviceName=probe&query.searchDepth=20" 2>/dev/null || true)"
  if jq -e '[.result.resourceSpans[]?.scopeSpans[]?.spans[]?.events[]? | select(.name == "exception")] | length >= 1' <<<"$response" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 5
done
echo 'Jaeger did not return a probe trace with an exception event in time' >&2
exit 1

#!/usr/bin/env bash
# Grader: Jaeger in the namespace tracing holds spans of the service probe from
# the last 3 minutes, and they carry the status ERROR and an exception event.
# Reads the Jaeger v3 API on port 16686 through the API server proxy. Retries
# for up to two minutes, because Jaeger batches spans before it stores them.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# probe_env NAME: the value of one environment variable of the probe container.
probe_env() {
  jq -r --arg name "$1" '[.spec.template.spec.containers[] | select(.name == "probe") | .env[]? | select(.name == $name) | .value] | first // ""' <<<"$DEPLOYMENT"
}

# The task changes only OTEL_ENABLED and OTEL_EXPORTER_OTLP_ENDPOINT. The
# Deployment probe must stay in outpost with its service name, and its
# TARGET_URL must keep failing: the exceptions it records are the evidence.
check_design_kept() {
  DEPLOYMENT="$(kubectl -n outpost get deployment probe -o json 2>/dev/null)" \
    || fail "Deployment probe is missing in namespace outpost (do not delete or move it)"
  [ "$(probe_env TRACE_SERVICE)" = "probe" ] \
    || fail "TRACE_SERVICE of probe is '$(probe_env TRACE_SERVICE)'; keep it probe"
  [ "$(probe_env TARGET_URL)" = "http://relay.outpost:8080" ] \
    || fail "TARGET_URL of probe is '$(probe_env TARGET_URL)'; keep it http://relay.outpost:8080, its exceptions are the evidence"
}

check_design_kept

api=/api/v1/namespaces/tracing/services/jaeger:16686/proxy/api/v3/traces
count=0
for attempt in $(seq 1 24); do
  start="$(jq -rn 'now - 180 | floor | strftime("%Y-%m-%dT%H:%M:%SZ")')"
  end="$(jq -rn 'now + 60 | floor | strftime("%Y-%m-%dT%H:%M:%SZ")')"
  count="$(kubectl get --raw "$api?query.serviceName=probe&query.startTimeMin=$start&query.startTimeMax=$end&query.searchDepth=20" 2>/dev/null |
    jq -s '[.[].result.resourceSpans[]?.scopeSpans[]?.spans[]? | select(.events[]?.name == "exception")] | length' 2>/dev/null)"
  [ "${count:-0}" -gt 0 ] && { echo "PASS: Jaeger holds $count recent probe spans with an exception event"; exit 0; }
  sleep 5
done
fail "Jaeger in namespace tracing has no span of service probe from the last 3 minutes"

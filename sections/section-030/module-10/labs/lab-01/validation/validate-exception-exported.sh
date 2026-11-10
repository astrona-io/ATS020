#!/usr/bin/env bash
# Grader: /tmp/ats-020-exception.json holds the exception span events of
# probe, copied from the Jaeger API and not written by hand. Every exported
# event must match an exception that the running Jaeger holds for probe.
# The lab starts with no such file.
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

export_file="${ATS_EXCEPTION_FILE:-/tmp/ats-020-exception.json}"
[ -s "$export_file" ] || fail "$export_file does not exist or is empty"
jq -e '
  type == "array" and length >= 1 and
  all(.[]; type == "object" and .name == "exception" and
    ([.attributes[]?.key] | (index("exception.type") != null and index("exception.message") != null and index("exception.stacktrace") != null)))
' "$export_file" >/dev/null 2>&1 \
  || fail "$export_file must be a JSON array of span events named exception, each with exception.type, exception.message and exception.stacktrace, as /api/v3/traces returns them"

# pair: one "type|message" string for an exception event.
pair='(([.attributes[] | select(.key == "exception.type") | .value.stringValue] | first // "") + "|" + ([.attributes[] | select(.key == "exception.message") | .value.stringValue] | first // ""))'
api=/api/v1/namespaces/tracing/services/jaeger:16686/proxy/api/v3/traces
window='query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2100-01-01T00:00:00Z'
live=""
for attempt in 1 2 3; do
  live="$(kubectl get --raw "$api?$window&query.serviceName=probe&query.searchDepth=1500" 2>/dev/null |
    jq -sc "[.[].result.resourceSpans[]?.scopeSpans[]?.spans[]?.events[]? | select(.name == \"exception\") | $pair] | unique" 2>/dev/null)"
  [ -n "$live" ] && [ "$live" != "[]" ] && break
  live=""
  sleep 2
done
[ -n "$live" ] || fail "the running Jaeger returns no exception event for probe; send its spans to Jaeger first, then export them"
jq -e --argjson live "$live" "all(.[]; ($pair) as \$event | \$live | index(\$event) != null)" "$export_file" >/dev/null 2>&1 \
  || fail "an event in $export_file does not match any exception of probe in the running Jaeger; copy the events from the API response, do not write them by hand"
echo "PASS: $export_file holds $(jq length "$export_file") exception events of probe that Jaeger also holds"

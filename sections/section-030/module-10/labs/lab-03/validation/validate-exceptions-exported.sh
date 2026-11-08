#!/usr/bin/env bash
# Grader: the export file is a JSON array of span events named "exception",
# each with the exception.type and exception.message attributes, and every
# exported event exists in the running Jaeger for the failing service. A file
# typed by hand or kept from another attempt does not pass. Jaeger keeps traces
# in memory, so a Jaeger restart also empties this evidence.
set -uo pipefail
api=/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces
window='query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2100-01-01T00:00:00Z'
export_file=/tmp/ats-020-exceptions.json
fail() { echo "FAIL: exceptions-exported: $*" >&2; exit 1; }
[ -s "$export_file" ] || fail "$export_file does not exist or is empty"
jq -e '
  type == "array" and length >= 1 and
  all(.[]; type == "object" and .name == "exception" and
    ([.attributes[]?.key] | (index("exception.type") != null and index("exception.message") != null)))
' "$export_file" >/dev/null 2>&1 ||
  fail "$export_file must be a JSON array of span events named exception, each with the attributes exception.type and exception.message, as /api/v3/traces returns them"

# pair: one "type|message" string for an exception event.
pair='(([.attributes[] | select(.key == "exception.type") | .value.stringValue] | first // "") + "|" + ([.attributes[] | select(.key == "exception.message") | .value.stringValue] | first // ""))'
live_pairs=""
for attempt in 1 2 3; do
  live_pairs="$(kubectl get --raw "$api?$window&query.serviceName=probe&query.searchDepth=1500" 2>/dev/null |
    jq -c "[.result.resourceSpans[]?.scopeSpans[]?.spans[]?.events[]? | select(.name == \"exception\") | $pair] | unique" 2>/dev/null)" && [ -n "$live_pairs" ] && break
  live_pairs=""
  sleep 2
done
[ -n "$live_pairs" ] || fail "the running Jaeger returned no traces of the failing service; export the events again"
jq -e --argjson live "$live_pairs" "all(.[]; ($pair) as \$event | \$live | index(\$event) != null)" "$export_file" >/dev/null 2>&1 ||
  fail "an exported exception event does not exist in the running Jaeger for the failing service; copy the events from the API response, do not write them by hand"
echo "PASS: exceptions-exported"

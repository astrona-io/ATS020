#!/usr/bin/env bash
# Grader: compare each exported trace with the running Jaeger, so a file that
# was typed by hand or kept from another attempt does not pass. Jaeger keeps
# traces in memory, so a Jaeger restart also empties this evidence.
set -uo pipefail
export_file=/tmp/ats-020-incident-traces.json
fail() { echo "FAIL: export-live: $*" >&2; exit 1; }
[ -s "$export_file" ] || fail "$export_file does not exist or is empty"
span_ids='[.result.resourceSpans[].scopeSpans[]?.spans[]? | select(.traceId == $id) | .spanId] | sort'
trace_ids="$(jq -r '[.result.resourceSpans[].scopeSpans[]?.spans[]?.traceId] | unique | .[]' "$export_file" 2>/dev/null)" ||
  fail "$export_file is not a Jaeger API response"
[ -n "$trace_ids" ] || fail "$export_file holds no spans"
for trace_id in $trace_ids; do
  [[ "$trace_id" =~ ^[0-9a-f]{32}$ ]] || fail "$export_file holds a malformed trace ID"
  live_trace=""
  for attempt in 1 2 3; do
    live_trace="$(kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces/$trace_id" 2>/dev/null)" && break
    live_trace=""
    sleep 2
  done
  [ -n "$live_trace" ] || fail "trace $trace_id is not in the running Jaeger; export it again"
  jq -e '
    all(.result.resourceSpans[];
      [.resource.attributes[]? | select(.key == "service.name") | .value.stringValue] == ["scout"])
  ' <<<"$live_trace" >/dev/null 2>&1 || fail "trace $trace_id in the running Jaeger is not from the requested service"
  file_spans="$(jq -c --arg id "$trace_id" "$span_ids" "$export_file")"
  live_spans="$(jq -c --arg id "$trace_id" "$span_ids" <<<"$live_trace")"
  [ "$file_spans" = "$live_spans" ] || fail "trace $trace_id in the file does not have the spans it has in the running Jaeger"
done
echo "PASS: export-live"

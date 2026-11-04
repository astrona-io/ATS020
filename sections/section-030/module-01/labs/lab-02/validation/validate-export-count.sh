#!/usr/bin/env bash
# Grader: the file is one /api/v3/traces response. Jaeger 2.22.0 answers with
# {"result":{"resourceSpans":[{"resource":...,"scopeSpans":[{"spans":[...]}]}]}}.
# A trace can fill more than one resourceSpans entry, so the grader counts
# distinct span traceId values, not entries. Every entry must name the service.
set -euo pipefail
export_file=/tmp/ats-020-incident-traces.json
fail() { echo "FAIL: export-count: $*" >&2; exit 1; }
[ -s "$export_file" ] || fail "$export_file does not exist or is empty"
jq -e -s --arg service scout --argjson wanted 5 '
  length == 1 and (.[0] |
    (.result.resourceSpans | type == "array" and length > 0) and
    ([.result.resourceSpans[].scopeSpans[]?.spans[]?.traceId] as $ids |
      all($ids[]; type == "string" and test("^[0-9a-f]{32}$")) and
      ($ids | unique | length) == $wanted) and
    all(.result.resourceSpans[];
      [.resource.attributes[]? | select(.key == "service.name") | .value.stringValue] == [$service]))
' "$export_file" >/dev/null 2>&1 ||
  fail "$export_file must be the unchanged /api/v3/traces JSON response, with exactly 5 distinct traces, all from the service behind incident.code=retry-storm"
echo "PASS: export-count"

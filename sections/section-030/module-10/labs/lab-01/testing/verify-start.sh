#!/usr/bin/env bash
# Run by `astrona test` before the reference solution. Proves the lab starts
# with the intended faults and nothing solved, and that every grader fails on
# the untouched lab with an explicit grading failure.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

kubectl -n outpost get deployment probe -o json | jq -e '
  [.spec.template.spec.containers[] | select(.name == "probe") | .env[] | {(.name): .value}] | add
  | .OTEL_ENABLED == "false"
    and .OTEL_EXPORTER_OTLP_ENDPOINT == "http://jaeger.observability:4318"
    and .TARGET_URL == "http://relay.outpost:8080"' >/dev/null \
  || { echo 'FAIL: probe does not start with OTEL_ENABLED=false and the observability endpoint'; exit 1; }
! kubectl get namespace observability >/dev/null 2>&1 \
  || { echo 'FAIL: the namespace observability exists, so the start endpoint could resolve'; exit 1; }
[ ! -e /tmp/ats-020-exception.json ] \
  || { echo 'FAIL: /tmp/ats-020-exception.json exists before the learner starts'; exit 1; }
# Jaeger lists its own service jaeger; probe must not be there yet.
kubectl get --raw /api/v1/namespaces/tracing/services/jaeger:16686/proxy/api/v3/services \
  | jq -e '.services // [] | index("probe") == null' >/dev/null \
  || { echo 'FAIL: Jaeger already lists probe before the fix'; exit 1; }

output=$(mktemp)
trap 'rm -f "$output"' EXIT
for grader in "$lab_dir"/validation/validate-*.sh; do
  if bash "$grader" >"$output" 2>&1; then
    cat "$output"; echo "FAIL: $(basename "$grader") passed on the untouched lab"; exit 1
  fi
  grep -q '^FAIL:' "$output" || { cat "$output"; echo "FAIL: $(basename "$grader") gave no explicit grading failure"; exit 1; }
done
echo 'PASS: nothing is solved at the start, and every grader fails on the untouched lab'

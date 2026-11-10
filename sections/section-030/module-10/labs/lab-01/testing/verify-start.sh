#!/usr/bin/env bash
# Run by `astrona test` before the reference solution. Proves the lab starts
# with the intended fault, and that every grader fails on the untouched lab.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

kubectl -n observability get opentelemetrycollector otel -o json \
  | jq -e '.spec.config.exporters.otlp_grpc | .endpoint == "jaeger-collector.observability:4317" and (.tls.insecure // false) == false' >/dev/null \
  || { echo 'FAIL: the Collector does not start with the exporter faults'; exit 1; }

output=$(mktemp)
trap 'rm -f "$output"' EXIT
for grader in "$lab_dir"/validation/validate-*.sh; do
  if bash "$grader" >"$output" 2>&1; then
    cat "$output"; echo "FAIL: $(basename "$grader") passed on the untouched lab"; exit 1
  fi
  grep -q '^FAIL:' "$output" || { cat "$output"; echo "FAIL: $(basename "$grader") gave no explicit grading failure"; exit 1; }
done
echo 'PASS: every grader fails on the untouched lab'

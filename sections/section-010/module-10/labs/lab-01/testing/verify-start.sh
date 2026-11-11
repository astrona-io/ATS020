#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl -n starfleet get servicemonitor scout -o json | jq -e '.metadata.labels.release == "prometheus" and .spec.endpoints[0].port == "metrics" and .spec.endpoints[0].path == "/metric"' >/dev/null || { echo 'FAIL: missing discovery fault'; exit 1; }
# Nothing is solved at the start: every grader must fail on the untouched lab
# with an explicit grading failure. Retry delays are skipped, because this
# check only needs the failure.
output=$(mktemp)
trap 'rm -f "$output"' EXIT
problems=0
for grader in "$lab_dir"/validation/validate-*.sh; do
  if (sleep() { :; }; export -f sleep; bash "$grader") >"$output" 2>&1; then
    cat "$output"; echo "FAIL: $(basename "$grader") passed on the untouched lab"; problems=1
  elif ! grep -q '^FAIL:' "$output"; then
    cat "$output"; echo "FAIL: $(basename "$grader") gave no explicit grading failure"; problems=1
  fi
done
[ "$problems" = 0 ] || exit 1
echo 'PASS: the intended fault is present, and every grader fails on the untouched lab'

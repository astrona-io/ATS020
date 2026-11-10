#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: starting state: $*" >&2; exit 1; }
kubectl -n monitoring get prometheusrule scout-queries -o json | jq -e --arg expr 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m]))' '.spec.groups[0].rules[1].expr == $expr' >/dev/null || fail 'expected faulty expression is missing'
# Nothing is solved at the start: every grader must fail on the untouched lab
# with an explicit grading failure. Retry delays are skipped, because this
# check only needs the failure.
output=$(mktemp)
trap 'rm -f "$output"' EXIT
for grader in "$lab_dir"/validation/validate-*.sh; do
  if (sleep() { :; }; export -f sleep; bash "$grader") >"$output" 2>&1; then
    cat "$output"; echo "FAIL: $(basename "$grader") passed on the untouched lab"; exit 1
  fi
  grep -q '^FAIL:' "$output" || { cat "$output"; echo "FAIL: $(basename "$grader") gave no explicit grading failure"; exit 1; }
done
echo 'PASS: the intended fault is present, and every grader fails on the untouched lab'

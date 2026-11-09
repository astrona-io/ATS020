#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: starting state: $*" >&2; exit 1; }
kubectl -n monitoring get prometheusrule scout-queries -o json | jq -e --arg expr 'sum(rate(http_requests_total{namespace="starfleet",status=~"5.."}[5m])) / sum(http_requests_total{namespace="starfleet"})' '.spec.groups[0].rules[0].expr == $expr' >/dev/null || fail 'expected faulty expression is missing'
output=$(mktemp)
trap 'rm -f "$output"' EXIT
# The fault was checked above. Skip retry delays only for this negative check.
if (sleep() { :; }; export -f sleep; bash "$lab_dir/validation/validate-error-ratio.sh") >"$output" 2>&1; then
  cat "$output"
  fail "the unfinished lab passed its grader"
fi
grep -q '^FAIL:' "$output" || { cat "$output"; fail "grader failed without a grading result"; }
echo 'PASS: intended fault is present and the unfinished lab fails grading'

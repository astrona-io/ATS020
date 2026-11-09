#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl -n monitoring get prometheusrule scout-slo -o json | jq -e '[.spec.groups[0].rules[] | select(.record) | .expr | contains("5xx")] | length == 2 and all' >/dev/null || { echo 'FAIL: missing status-selector fault'; exit 1; }
output=$(mktemp)
trap 'rm -f "$output"' EXIT
if (sleep() { :; }; export -f sleep; bash "$lab_dir/validation/validate-error-ratio.sh") >"$output" 2>&1; then
 cat "$output"; echo 'FAIL: the unfinished lab passed its grader'; exit 1
fi
grep -q '^FAIL:' "$output" || { cat "$output"; echo 'FAIL: no explicit grading failure'; exit 1; }
echo 'PASS: the intended unfinished task fails grading'

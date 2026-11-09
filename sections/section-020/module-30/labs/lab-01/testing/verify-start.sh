#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: starting state: $*" >&2; exit 1; }
kubectl -n monitoring get deployment kps-grafana >/dev/null
output=$(mktemp)
trap 'rm -f "$output"' EXIT
if bash "$lab_dir/validation/validate-data-source.sh" >"$output" 2>&1; then
  cat "$output"
  fail "the unfinished lab passed its grader"
fi
grep -q '^FAIL: Maximum lines is not 250$' "$output" || { cat "$output"; fail "grader did not reject the intended Maximum lines fault"; }
echo 'PASS: intended fault is present and the unfinished lab fails grading'

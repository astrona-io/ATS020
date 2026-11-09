#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: starting state: $*" >&2; exit 1; }
[ "$(kubectl -n argocd get application scout -o json | jq '.status.history | length')" = 10 ] || fail 'history is incomplete'
if kubectl -n starfleet get configmap delivery-evidence >/dev/null 2>&1; then fail 'evidence already exists'; fi
output=$(mktemp)
trap 'rm -f "$output"' EXIT
# The fault was checked above. Skip retry delays only for this negative check.
if (sleep() { :; }; export -f sleep; bash "$lab_dir/validation/validate-evidence.sh") >"$output" 2>&1; then
  cat "$output"
  fail "the unfinished lab passed its grader"
fi
grep -q '^FAIL:' "$output" || { cat "$output"; fail "grader failed without a grading result"; }
echo 'PASS: intended fault is present and the unfinished lab fails grading'

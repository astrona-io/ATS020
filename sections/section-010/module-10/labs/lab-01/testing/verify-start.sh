#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl -n starfleet get servicemonitor scout -o json | jq -e '.metadata.labels.release == "prometheus" and .spec.endpoints[0].port == "metrics" and .spec.endpoints[0].path == "/metric"' >/dev/null || { echo 'FAIL: missing discovery fault'; exit 1; }
output=$(mktemp)
trap 'rm -f "$output"' EXIT
if (sleep() { :; }; export -f sleep; bash "$lab_dir/validation/validate-targets-up.sh") >"$output" 2>&1; then
 cat "$output"; echo 'FAIL: the unfinished lab passed its grader'; exit 1
fi
grep -q '^FAIL:' "$output" || { cat "$output"; echo 'FAIL: no explicit grading failure'; exit 1; }
echo 'PASS: the intended unfinished task fails grading'

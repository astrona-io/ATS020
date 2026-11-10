#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: starting state: $*" >&2; exit 1; }
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/silences | jq -e 'all(.[]; .status.state != "active")' >/dev/null || fail 'an active silence already exists'
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

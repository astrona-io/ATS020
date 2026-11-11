#!/usr/bin/env bash
# Run by `astrona test` before the reference solution.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fault() { echo "FAIL: missing starting fault: $*"; exit 1; }
# The four seeded faults are in place.
[ "$(kubectl -n starfleet get deployment cargo -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')" = "48Mi" ] \
  || fault "cargo memory limit 48Mi"
[ "$(kubectl -n starfleet get deployment beacon -o jsonpath='{.spec.template.spec.containers[0].image}')" = "ghcr.io/stefanprodan/podinfo:v6.17.0" ] \
  || fault "beacon image tag v6.17.0"
[ "$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}')" = "8081" ] \
  || fault "probe liveness probe on port 8081"
[ "$(kubectl -n webhook-system get service starfleet-policy -o jsonpath='{.spec.selector.app}')" = "starfleet-policy-v2" ] \
  || fault "starfleet-policy Service selector app=starfleet-policy-v2"
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

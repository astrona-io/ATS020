#!/usr/bin/env bash
# Run by `astrona test` before the reference solution. Proves the lab starts
# with the intended state and nothing solved, and that every grader fails on
# the untouched lab with an explicit grading failure.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

env_of() {
  kubectl -n starfleet get deployment "$1" -o json |
    jq -c --arg name "$1" '[.spec.template.spec.containers[] | select(.name == $name) | .env[] | {(.name): .value}] | add'
}
jq -e '.INCIDENT_CODE == "retry-storm" and .RESPONSE_DELAY_MS == "800"' <<<"$(env_of scout)" >/dev/null \
  || { echo 'FAIL: scout does not start with incident.code=retry-storm and RESPONSE_DELAY_MS=800'; exit 1; }
for name in probe shuttle; do
  jq -e '.RESPONSE_DELAY_MS == "50"' <<<"$(env_of "$name")" >/dev/null \
    || { echo "FAIL: $name does not start with RESPONSE_DELAY_MS=50"; exit 1; }
done
kubectl -n starfleet get deployment probe shuttle -o json | jq -e 'all(.items[]; .spec.replicas == 1)' >/dev/null \
  || { echo 'FAIL: probe and shuttle do not start with one replica'; exit 1; }
[ ! -e /tmp/ats-020-incident-traces.json ] \
  || { echo 'FAIL: /tmp/ats-020-incident-traces.json exists before the learner starts'; exit 1; }

output=$(mktemp)
trap 'rm -f "$output"' EXIT
for grader in "$lab_dir"/validation/validate-*.sh; do
  if bash "$grader" >"$output" 2>&1; then
    cat "$output"; echo "FAIL: $(basename "$grader") passed on the untouched lab"; exit 1
  fi
  grep -q '^FAIL:' "$output" || { cat "$output"; echo "FAIL: $(basename "$grader") gave no explicit grading failure"; exit 1; }
done
echo 'PASS: nothing is solved at the start, and every grader fails on the untouched lab'

#!/usr/bin/env bash
# Run by `astrona test` before the reference solution. Proves the lab starts
# with the intended fault and nothing solved, and that every grader fails on
# the untouched lab with an explicit grading failure.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

kubectl -n starfleet get deployment probe -o json | jq -e '
  [.spec.template.spec.containers[] | select(.name == "probe") | .env[] | {(.name): .value}] | add
  | .TARGET_URL == "http://relay.starfleet:8080"' >/dev/null \
  || { echo 'FAIL: probe does not start with TARGET_URL=http://relay.starfleet:8080'; exit 1; }
! kubectl -n starfleet get service relay >/dev/null 2>&1 \
  || { echo 'FAIL: the Service relay exists, so probe would not fail'; exit 1; }
for file in /tmp/ats-020-error-service.txt /tmp/ats-020-exceptions.json; do
  [ ! -e "$file" ] || { echo "FAIL: $file exists before the learner starts"; exit 1; }
done

output=$(mktemp)
trap 'rm -f "$output"' EXIT
for grader in "$lab_dir"/validation/validate-*.sh; do
  if bash "$grader" >"$output" 2>&1; then
    cat "$output"; echo "FAIL: $(basename "$grader") passed on the untouched lab"; exit 1
  fi
  grep -q '^FAIL:' "$output" || { cat "$output"; echo "FAIL: $(basename "$grader") gave no explicit grading failure"; exit 1; }
done
echo 'PASS: nothing is solved at the start, and every grader fails on the untouched lab'

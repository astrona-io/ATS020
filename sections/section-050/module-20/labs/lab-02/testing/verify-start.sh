#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: starting state: $*" >&2; exit 1; }
cert=$(mktemp)
kubectl -n webhook-system get secret outpost-policy-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > "$cert"
if openssl x509 -in "$cert" -checkend 0 -noout; then rm -f "$cert"; fail 'the serving certificate is not expired'; fi
rm -f "$cert"

output=$(mktemp)
trap 'rm -f "$output"' EXIT
# The fault was checked above. Skip retry delays only for this negative check.
if (sleep() { :; }; export -f sleep; bash "$lab_dir/validation/validate-outpost-webhook.sh") >"$output" 2>&1; then
  cat "$output"
  fail "the unfinished lab passed its grader"
fi
grep -q '^FAIL:' "$output" || { cat "$output"; fail "grader failed without a grading result"; }
echo 'PASS: intended fault is present and the unfinished lab fails grading'

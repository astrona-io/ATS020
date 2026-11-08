#!/usr/bin/env bash
# Grader: the answer file names the one service whose spans end with an error
# status. The manifest sends those spans from probe.
set -uo pipefail
answer_file=/tmp/ats-020-error-service.txt
fail() { echo "FAIL: service-named: $*" >&2; exit 1; }
[ -s "$answer_file" ] || fail "$answer_file does not exist or is empty"
answer="$(tr -d '[:space:]' <"$answer_file")"
[ "$answer" = "probe" ] || fail "$answer_file names '$answer'; it must hold only the name of the service whose spans carry an error status"
echo "PASS: service-named"

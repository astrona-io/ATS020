#!/usr/bin/env bash
# Confirm the intended fault and prove the injection grader rejects it.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRADER=""
for candidate in "$SCRIPT_DIR/../validation/validate-injection.sh" "./validation/validate-injection.sh"; do
  [ -f "$candidate" ] && { GRADER="$candidate"; break; }
done
[ -n "$GRADER" ] || { echo "FAIL: injection grader not found" >&2; exit 1; }
pod=$(kubectl -n starfleet get pods -l app=relay -o json | jq '.items[] | select(.metadata.deletionTimestamp == null)')
kubectl -n observability get instrumentation nodejs -o json | jq -e '.spec.propagators == ["tracecontext", "baggage"]' >/dev/null
printf '%s' "$pod" | jq -e '(.spec.initContainers // []) | length == 0' >/dev/null
if bash "$GRADER"; then
  echo "FAIL: the unfinished starting state passed the injection grader" >&2
  exit 1
fi
echo "PASS: the intended starting fault is present and the grader rejects it"

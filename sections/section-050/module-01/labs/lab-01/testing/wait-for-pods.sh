#!/usr/bin/env bash
# Helper for `astrona test`: waits until each of the four Deployments has a
# ready pod, so the validation scripts do not start while pods are replaced.
set -uo pipefail

for attempt in $(seq 1 60); do
  READY=0
  for name in scout probe cargo beacon; do
    COUNT="$(kubectl -n starfleet get deployment "$name" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
    [ "${COUNT:-0}" -ge 1 ] && READY=$((READY + 1))
  done
  if [ "$READY" -eq 4 ]; then
    echo "[testing] all four Deployments are ready."
    exit 0
  fi
  sleep 5
done
echo "[testing] not all Deployments became ready in time (continuing)." >&2
exit 0

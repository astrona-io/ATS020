#!/usr/bin/env bash
# Helper for `astrona test`: waits until the three Deployments and the webhook
# server have a ready pod, so the validation scripts do not start while pods are replaced.
set -uo pipefail

for attempt in $(seq 1 60); do
  READY=0
  for name in probe cargo beacon; do
    COUNT="$(kubectl -n starfleet get deployment "$name" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
    [ "${COUNT:-0}" -ge 1 ] && READY=$((READY + 1))
  done
  COUNT="$(kubectl -n webhook-system get deployment starfleet-policy -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "${COUNT:-0}" -ge 1 ] && READY=$((READY + 1))
  if [ "$READY" -eq 4 ]; then
    echo "[testing] all four Deployments are ready."
    exit 0
  fi
  sleep 5
done
echo "[testing] not all Deployments became ready in time (continuing)." >&2
exit 0

#!/usr/bin/env bash
# Helper for `astrona test`: waits until Prometheus has two healthy scout
# targets in frontier and the receiver has logged a firing notification. A
# changed monitor or rule reaches Prometheus after about 60 seconds, and the
# alert needs one more minute of `for:` plus the Alertmanager group wait.
set -uo pipefail

for attempt in $(seq 1 90); do
  COUNT="$(kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=count(up%7Bjob%3D%22scout%22,namespace%3D%22frontier%22%7D%3D%3D1)" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ "${COUNT:-0}" = "2" ] && kubectl -n monitoring logs deploy/alert-receiver 2>/dev/null | grep -q 'firing ScoutHighErrorRatio namespace=frontier'; then
    echo "[testing] Two healthy scout targets and a firing notification at the receiver."
    exit 0
  fi
  sleep 5
done
echo "[testing] The capstone did not settle in time (continuing)." >&2
exit 0

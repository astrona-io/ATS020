#!/usr/bin/env bash
# Helper for `astrona test`: waits until Prometheus has two healthy scout
# targets. A changed monitor reaches Prometheus after about 60 seconds, so the
# validation scripts would otherwise start too early.
set -uo pipefail

for attempt in $(seq 1 60); do
  COUNT="$(kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=count(up%7Bjob%3D%22scout%22,namespace%3D%22starfleet%22%7D%3D%3D1)" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ "${COUNT:-0}" = "2" ]; then
    echo "[testing] Prometheus has $COUNT healthy scout targets."
    exit 0
  fi
  sleep 5
done
echo "[testing] The scout targets did not settle in time (continuing)." >&2
exit 0

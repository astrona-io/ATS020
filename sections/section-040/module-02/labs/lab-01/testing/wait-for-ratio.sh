#!/usr/bin/env bash
# Helper for `astrona test`: waits until Prometheus returns the fixed error
# ratio. A changed rule reaches Prometheus after about 60 seconds, so the
# validation scripts would otherwise start too early.
set -uo pipefail

for attempt in $(seq 1 60); do
  VALUE="$(kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=scout:error_ratio:rate1h" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ -n "$VALUE" ] && awk -v v="$VALUE" 'BEGIN {exit !(v > 0.03 && v < 0.08)}'; then
    echo "[testing] The error ratio over one hour is $VALUE."
    exit 0
  fi
  sleep 5
done
echo "[testing] The error ratio did not settle in time (continuing)." >&2
exit 0

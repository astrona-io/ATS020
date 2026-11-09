#!/usr/bin/env bash
# Helper for `astrona test`: waits until Prometheus holds memory usage for
# scout and probe, so the graders have a measured peak to compare with.
set -uo pipefail

for attempt in $(seq 1 60); do
  COUNT="$(kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=count(container_memory_working_set_bytes%7Bnamespace%3D%22starfleet%22%2Ccontainer%3D~%22scout%7Cprobe%22%7D)" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // 0' 2>/dev/null)"
  if [ "${COUNT:-0}" -ge 3 ] 2>/dev/null; then
    echo "[testing] Prometheus holds usage for $COUNT containers."
    exit 0
  fi
  sleep 5
done
echo "[testing] Usage data did not appear in time (continuing)." >&2
exit 0

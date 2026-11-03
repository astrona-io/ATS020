#!/usr/bin/env bash
# Helper for `astrona test`: waits until the recorded series exist and
# Prometheus holds memory usage for beacon, so the graders have data. A new
# rule reaches Prometheus after about 60 seconds.
set -uo pipefail

prom() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$1" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // empty' 2>/dev/null
}

for attempt in $(seq 1 72); do
  A="$(prom 'dora:change_failure_rate:ratio6h')"
  B="$(prom 'scout:error_budget_remaining:ratio1h')"
  C="$(prom 'container_memory_working_set_bytes%7Bnamespace%3D%22starfleet%22%2Ccontainer%3D%22beacon%22%7D')"
  if [ -n "$A" ] && [ -n "$B" ] && [ -n "$C" ]; then
    echo "[testing] Series exist and beacon usage is known."
    exit 0
  fi
  sleep 5
done
echo "[testing] Data did not appear in time (continuing)." >&2
exit 0

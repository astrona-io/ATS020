#!/usr/bin/env bash
# Helper for `astrona test`: waits until the fixed Collector has accepted and
# sent spans, so the validation scripts see a settled pipeline. Telemetry is
# late: scout exports in batches and the Collector batches again.
set -uo pipefail

POD=""
for attempt in $(seq 1 60); do
  POD="$(kubectl -n observability get pod -l app.kubernetes.io/component=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -n "$POD" ]; then
    SENT="$(kubectl get --raw "/api/v1/namespaces/observability/pods/${POD}:8888/proxy/metrics" 2>/dev/null | awk '/^otelcol_exporter_sent_spans/ {s+=$NF} END {print s+0}')"
    if [ "${SENT:-0}" -gt 0 ]; then
      echo "[testing] Collector has sent ${SENT} spans."
      exit 0
    fi
  fi
  sleep 5
done
echo "[testing] Collector did not send spans in time (continuing)." >&2
exit 0

#!/usr/bin/env bash
# Grader: the Collector's own counters show spans going in and out. Reads
# port 8888 of the Collector pod through the API server proxy. Retries,
# because telemetry is late.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

for attempt in $(seq 1 36); do
  POD="$(kubectl -n observability get pod -l app.kubernetes.io/component=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -n "$POD" ]; then
    METRICS="$(kubectl get --raw "/api/v1/namespaces/observability/pods/${POD}:8888/proxy/metrics" 2>/dev/null || true)"
    ACCEPTED="$(printf '%s\n' "$METRICS" | awk '/^otelcol_receiver_accepted_spans/ {s+=$NF} END {print s+0}')"
    SENT="$(printf '%s\n' "$METRICS" | awk '/^otelcol_exporter_sent_spans/ {s+=$NF} END {print s+0}')"
    if [ "${ACCEPTED:-0}" -gt 0 ] && [ "${SENT:-0}" -gt 0 ]; then
      echo "PASS: pod $POD accepted $ACCEPTED spans and sent $SENT spans"
      exit 0
    fi
  fi
  sleep 5
done
fail "the Collector has not both accepted and sent spans (accepted=${ACCEPTED:-0}, sent=${SENT:-0})"

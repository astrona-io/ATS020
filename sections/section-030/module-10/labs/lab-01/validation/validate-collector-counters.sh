#!/usr/bin/env bash
# Grader: the Collector's own counters show spans going in and out. Reads
# port 8888 of the Collector pod through the API server proxy. Retries,
# because telemetry is late, for up to two minutes, but fails after 30
# seconds of spans arriving while none leave: waiting longer cannot help.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

STUCK=0
for attempt in $(seq 1 24); do
  POD="$(kubectl -n observability get pod -l app.kubernetes.io/component=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -n "$POD" ]; then
    METRICS="$(kubectl get --raw "/api/v1/namespaces/observability/pods/${POD}:8888/proxy/metrics" 2>/dev/null || true)"
    ACCEPTED="$(printf '%s\n' "$METRICS" | awk '/^otelcol_receiver_accepted_spans/ {s+=$NF} END {print s+0}')"
    SENT="$(printf '%s\n' "$METRICS" | awk '/^otelcol_exporter_sent_spans/ {s+=$NF} END {print s+0}')"
    if [ "${ACCEPTED:-0}" -gt 0 ] && [ "${SENT:-0}" -gt 0 ]; then
      echo "PASS: pod $POD accepted $ACCEPTED spans and sent $SENT spans"
      exit 0
    fi
    if [ "${ACCEPTED:-0}" -gt 0 ]; then
      STUCK=$((STUCK + 1))
      [ "$STUCK" -ge 6 ] && fail "the Collector accepts spans but has sent none for 30 seconds (accepted=${ACCEPTED}, sent=0)"
    else
      STUCK=0
    fi
  fi
  sleep 5
done
fail "the Collector has not both accepted and sent spans (accepted=${ACCEPTED:-0}, sent=${SENT:-0})"

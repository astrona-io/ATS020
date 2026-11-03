#!/usr/bin/env bash
# Grader: the Collector `otel` exists in `observability`, has a traces
# pipeline with an OTLP receiver and a real exporter, the Service
# `otel-collector` has the OTLP gRPC port 4317, and the Collector's own
# counters show spans accepted and sent. Retries, because spans arrive late.
set -uo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }

kubectl -n observability get opentelemetrycollector otel >/dev/null 2>&1 \
  || fail "OpenTelemetryCollector otel is missing in namespace observability"
RECEIVERS="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.config.service.pipelines.traces.receivers[*]}' 2>/dev/null)"
case "$RECEIVERS" in *otlp*) ;; *) fail "the traces pipeline of the Collector has receivers '$RECEIVERS'; it needs the otlp receiver";; esac
EXPORTERS="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.config.service.pipelines.traces.exporters[*]}' 2>/dev/null)"
REAL=""
for name in $EXPORTERS; do
  case "$name" in debug*|logging*|nop*) ;; *) REAL="$REAL $name";; esac
done
[ -n "$REAL" ] || fail "the traces pipeline exports only to '$EXPORTERS'; it must export to Jaeger"
kubectl -n observability get service otel-collector -o jsonpath='{.spec.ports[*].port}' 2>/dev/null | grep -qw 4317 \
  || fail "the Service otel-collector in observability has no port 4317"

for attempt in $(seq 1 36); do
  POD="$(kubectl -n observability get pod -l app.kubernetes.io/component=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -n "$POD" ]; then
    METRICS="$(kubectl get --raw "/api/v1/namespaces/observability/pods/${POD}:8888/proxy/metrics" 2>/dev/null || true)"
    ACCEPTED="$(printf '%s\n' "$METRICS" | awk '/^otelcol_receiver_accepted_spans/ {sum += $NF} END {print sum + 0}')"
    SENT="$(printf '%s\n' "$METRICS" | awk '/^otelcol_exporter_sent_spans/ {sum += $NF} END {print sum + 0}')"
    if awk -v a="$ACCEPTED" -v s="$SENT" 'BEGIN { exit !(a > 0 && s > 0) }'; then
      echo "PASS: the Collector accepted $ACCEPTED spans and sent $SENT"
      exit 0
    fi
  fi
  sleep 5
done
fail "the Collector counters show accepted=${ACCEPTED:-0} sent=${SENT:-0}; spans do not flow through it"

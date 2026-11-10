#!/usr/bin/env bash
# Grader: the Collector's own counters show spans going in and out. Reads
# port 8888 of the Collector pod through the API server proxy. Retries,
# because telemetry is late, for up to two minutes, but fails after 30
# seconds of spans arriving while none leave: waiting longer cannot help.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The fix must stay inside the Collector: the same OpenTelemetryCollector in
# deployment mode, the Service otel-collector on 4317, scout still sending to
# it, and a real exporter (not only debug) in the traces pipeline. A bypass
# fails here, so it can never pass a check.
check_design_kept() {
  local mode ports endpoint exporters name real=""
  mode="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.mode}' 2>/dev/null)" \
    || fail "OpenTelemetryCollector otel is missing in namespace observability (do not delete it)"
  [ "$mode" = "deployment" ] || fail "Collector mode is '$mode', expected deployment"
  ports="$(kubectl -n observability get service otel-collector -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)" \
    || fail "Service otel-collector is missing"
  case " $ports " in *" 4317 "*) ;; *) fail "Service otel-collector has ports '$ports', expected 4317";; esac
  endpoint="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].env[?(@.name=="OTEL_EXPORTER_OTLP_ENDPOINT")].value}' 2>/dev/null)"
  [ "$endpoint" = "http://otel-collector.observability:4317" ] \
    || fail "scout sends to '$endpoint'; it must keep sending to http://otel-collector.observability:4317 (fix the Collector, not scout)"
  exporters="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.config.service.pipelines.traces.exporters[*]}' 2>/dev/null)"
  for name in $exporters; do
    case "$name" in debug*|logging*|nop*) ;; *) real="$real $name";; esac
  done
  [ -n "$real" ] || fail "the traces pipeline exports only to '${exporters:-nothing}'; it must export to Jaeger"
}

check_design_kept

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

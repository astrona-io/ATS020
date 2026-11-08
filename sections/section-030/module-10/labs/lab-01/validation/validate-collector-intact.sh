#!/usr/bin/env bash
# Grader: the fix keeps the design. The Collector `otel` still exists as a
# deployment-mode OpenTelemetryCollector, still takes OTLP gRPC on 4317
# through the Service `otel-collector`, and scout still sends to that Service
# (no bypass straight to Jaeger). The traces pipeline must still export to a
# real backend exporter, not only to `debug`.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

MODE="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.mode}' 2>/dev/null)" \
  || fail "OpenTelemetryCollector otel is missing in namespace observability (do not delete it)"
[ "$MODE" = "deployment" ] || fail "Collector mode is '$MODE', expected deployment"

PORTS="$(kubectl -n observability get service otel-collector -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)" \
  || fail "Service otel-collector is missing"
case " $PORTS " in *" 4317 "*) ;; *) fail "Service otel-collector has ports '$PORTS', expected 4317";; esac

ENDPOINT="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].env[?(@.name=="OTEL_EXPORTER_OTLP_ENDPOINT")].value}' 2>/dev/null)"
[ "$ENDPOINT" = "http://otel-collector.observability:4317" ] \
  || fail "scout sends to '$ENDPOINT'; it must keep sending to http://otel-collector.observability:4317 (fix the Collector, not scout)"

CONFIG="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.config.service.pipelines.traces.exporters[*]}' 2>/dev/null)"
[ -n "$CONFIG" ] || fail "the traces pipeline has no exporter"
REAL=""
for name in $CONFIG; do
  case "$name" in debug*|logging*|nop*) ;; *) REAL="$REAL $name";; esac
done
[ -n "$REAL" ] || fail "the traces pipeline exports only to '$CONFIG'; it must export to Jaeger"

echo "PASS: Collector otel is a deployment, Service otel-collector serves 4317, scout still sends to it"

#!/usr/bin/env bash
# Grader: the Collector `otel` exists in `observability`, has a traces
# pipeline with an OTLP receiver and a real exporter, the Service
# `otel-collector` has the OTLP gRPC port 4317, and the Collector's own
# counters show spans accepted and sent. Retries, because spans arrive late.
set -uo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): relay and scout keep
# their design and no tracing code was added by hand.
IMAGE="$(kubectl -n starfleet get deployment relay -o jsonpath='{.spec.template.spec.containers[?(@.name=="relay")].image}' 2>/dev/null)" \
  || fail "Deployment relay is missing in namespace starfleet (do not delete it)"
[ "$IMAGE" = "node:22-alpine" ] || fail "relay image is '$IMAGE', expected node:22-alpine"
COMMAND="$(kubectl -n starfleet get deployment relay -o jsonpath='{.spec.template.spec.containers[?(@.name=="relay")].command[*]}' 2>/dev/null)"
[ "$COMMAND" = "node /app/server.js" ] || fail "relay command is '$COMMAND', expected 'node /app/server.js'"
SCRIPT="$(kubectl -n starfleet get configmap relay-app -o jsonpath='{.data.server\.js}' 2>/dev/null)"
case "$SCRIPT" in *callScout*) ;; *) fail "server.js of relay was replaced";; esac
case "$SCRIPT" in *traceparent*|*opentelemetry*) fail "server.js of relay contains tracing code; use auto-instrumentation";; esac

SCOUT_ENDPOINT="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].env[?(@.name=="OTEL_EXPORTER_OTLP_ENDPOINT")].value}' 2>/dev/null)"
[ "$SCOUT_ENDPOINT" = "http://otel-collector.observability:4317" ] || fail "scout sends to '$SCOUT_ENDPOINT'; fix it to http://otel-collector.observability:4317 (OTLP over gRPC)"
SCOUT_ANN="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.metadata.annotations}' 2>/dev/null)"
case "$SCOUT_ANN" in *instrumentation.opentelemetry.io*) fail "scout has an instrumentation annotation; scout traces itself and must not be injected";; esac

MODE="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.mode}' 2>/dev/null)" \
  || fail "OpenTelemetryCollector otel is missing in namespace observability"
[ "$MODE" = "deployment" ] || fail "Collector mode is '$MODE', expected deployment"

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

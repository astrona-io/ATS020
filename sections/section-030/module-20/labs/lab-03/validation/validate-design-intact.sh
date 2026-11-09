#!/usr/bin/env bash
# Grader: the fix keeps the design. relay is still the same Deployment with the
# same image, command and script (no tracing code added by hand); scout is
# untouched and not given an agent; the Collector `otel` is still a
# deployment-mode Collector with a traces pipeline that exports to a real
# backend (not only to `debug`).
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

IMAGE="$(kubectl -n starfleet get deployment relay -o jsonpath='{.spec.template.spec.containers[?(@.name=="relay")].image}' 2>/dev/null)" \
  || fail "Deployment relay is missing in namespace starfleet (do not delete it)"
[ "$IMAGE" = "node:22-alpine" ] || fail "relay image is '$IMAGE', expected node:22-alpine"
COMMAND="$(kubectl -n starfleet get deployment relay -o jsonpath='{.spec.template.spec.containers[?(@.name=="relay")].command[*]}' 2>/dev/null)"
[ "$COMMAND" = "node /app/server.js" ] || fail "relay command is '$COMMAND', expected 'node /app/server.js' (no code changes: the Operator adds the agent)"

SCRIPT="$(kubectl -n starfleet get configmap relay-app -o jsonpath='{.data.server\.js}' 2>/dev/null)"
[ -n "$SCRIPT" ] || fail "ConfigMap relay-app has no server.js"
case "$SCRIPT" in *callScout*) ;; *) fail "server.js of relay was replaced";; esac
case "$SCRIPT" in *traceparent*|*opentelemetry*) fail "server.js of relay contains tracing code; this lab uses auto-instrumentation, not code changes";; esac

SCOUT_ENDPOINT="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].env[?(@.name=="OTEL_EXPORTER_OTLP_ENDPOINT")].value}' 2>/dev/null)"
[ "$SCOUT_ENDPOINT" = "http://otel-collector.observability:4317" ] || fail "scout sends to '$SCOUT_ENDPOINT'; it must keep sending to http://otel-collector.observability:4317"
SCOUT_ANN="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.metadata.annotations}' 2>/dev/null)"
case "$SCOUT_ANN" in *instrumentation.opentelemetry.io*) fail "scout has an instrumentation annotation; scout already traces itself and must not be injected";; esac

MODE="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.mode}' 2>/dev/null)" \
  || fail "OpenTelemetryCollector otel is missing in namespace observability"
[ "$MODE" = "deployment" ] || fail "Collector mode is '$MODE', expected deployment"
EXPORTERS="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.config.service.pipelines.traces.exporters[*]}' 2>/dev/null)"
REAL=""
for name in $EXPORTERS; do
  case "$name" in debug*|logging*|nop*) ;; *) REAL="$REAL $name";; esac
done
[ -n "$REAL" ] || fail "the Collector traces pipeline exports only to '$EXPORTERS'; it must export to Jaeger"

echo "PASS: relay and scout are unchanged in design, and the Collector still exports to Jaeger"

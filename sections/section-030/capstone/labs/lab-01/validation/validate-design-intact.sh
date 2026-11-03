#!/usr/bin/env bash
# Grader: the fix keeps the design. relay keeps its image, command and script
# (no tracing code added by hand); scout is not injected and keeps its
# endpoint on the Collector Service at the gRPC port 4317; the Collector
# `otel` is a deployment-mode Collector.
set -uo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }

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
echo "PASS: relay and scout keep their design, and the Collector is a deployment named otel"

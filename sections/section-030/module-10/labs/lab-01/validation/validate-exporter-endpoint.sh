#!/usr/bin/env bash
# Grader: the traces exporter of the Collector points at the Service jaeger in
# observability, on an OTLP port (4317 gRPC or 4318 HTTP). The starting
# exporter points at jaeger-collector, a Service that does not exist, so this
# check fails until that is fixed.
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

RESULT="$(kubectl -n observability get opentelemetrycollector otel -o json 2>/dev/null | python3 -c '
import json, re, sys
spec = json.load(sys.stdin)["spec"]["config"]
exporters = spec.get("exporters") or {}
hosts = {"jaeger", "jaeger.observability", "jaeger.observability.svc", "jaeger.observability.svc.cluster.local"}
seen = []
for name in spec["service"]["pipelines"]["traces"].get("exporters", []):
    if re.match(r"(debug|logging|nop)", name):
        continue
    endpoint = str((exporters.get(name) or {}).get("endpoint", ""))
    seen.append(endpoint or "no endpoint")
    address = re.sub(r"^(https?://|dns:///)", "", endpoint).split("/")[0]
    host, _, port = address.rpartition(":")
    if host in hosts and port in ("4317", "4318"):
        print("PASS " + endpoint)
        sys.exit(0)
print("FAIL " + ", ".join(seen))' 2>/dev/null)"

case "$RESULT" in
  "PASS "*) echo "PASS: the traces exporter sends to ${RESULT#PASS }, the Service jaeger" ;;
  *) fail "the traces exporter sends to '${RESULT#FAIL }', which is not the Service jaeger in observability on port 4317" ;;
esac

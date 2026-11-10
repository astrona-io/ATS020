#!/usr/bin/env bash
# Grader: a trace from scout, with a recent start time, is in Jaeger. Reads
# the Jaeger v3 API on port 16686 through the API server proxy. Retries,
# because scout and the Collector both batch spans before they export them,
# for up to two minutes. Stops after 30 seconds in which the Collector
# accepted spans but sent none, since then none can reach Jaeger.
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

# Prints "accepted sent" from the Collector's own counters, or nothing.
collector_counters() {
  local pod metrics
  pod="$(kubectl -n observability get pod -l app.kubernetes.io/component=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [ -n "$pod" ] || return 0
  metrics="$(kubectl get --raw "/api/v1/namespaces/observability/pods/${pod}:8888/proxy/metrics" 2>/dev/null || true)"
  printf '%s\n' "$metrics" | awk '/^otelcol_receiver_accepted_spans/ {a+=$NF} /^otelcol_exporter_sent_spans/ {s+=$NF} END {print a+0, s+0}'
}

STUCK=0
for attempt in $(seq 1 24); do
  START="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=3)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  END="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)+d.timedelta(minutes=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  BODY="$(kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces?query.service_name=scout&query.start_time_min=${START}&query.start_time_max=${END}&query.search_depth=20" 2>/dev/null || true)"
  COUNT="$(printf '%s' "$BODY" | python3 -c '
import json, sys
n = 0
for line in sys.stdin.read().splitlines():
    try:
        doc = json.loads(line)
    except ValueError:
        continue
    for rs in doc.get("result", {}).get("resourceSpans", []):
        names = [a["value"].get("stringValue") for a in rs.get("resource", {}).get("attributes", []) if a.get("key") == "service.name"]
        if "scout" in names:
            for ss in rs.get("scopeSpans", []):
                n += len(ss.get("spans", []))
print(n)' 2>/dev/null)"
  if [ "${COUNT:-0}" -gt 0 ]; then
    echo "PASS: Jaeger holds ${COUNT} recent spans from service scout"
    exit 0
  fi
  read -r ACCEPTED SENT <<<"$(collector_counters)"
  if [ "${ACCEPTED:-0}" -gt 0 ] && [ "${SENT:-0}" -eq 0 ]; then
    STUCK=$((STUCK + 1))
    [ "$STUCK" -ge 6 ] && fail "Jaeger has no span from service scout, and the Collector has sent none for 30 seconds"
  else
    STUCK=0
  fi
  sleep 5
done
fail "Jaeger has no span from service scout in the last 3 minutes"

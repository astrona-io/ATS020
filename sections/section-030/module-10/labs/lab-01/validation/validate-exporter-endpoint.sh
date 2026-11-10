#!/usr/bin/env bash
# Grader: OTEL_EXPORTER_OTLP_ENDPOINT of the Deployment probe is the OTLP/HTTP
# port of the Service jaeger in the namespace tracing. The lab starts with
# jaeger.observability, a namespace that does not exist.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# probe_env NAME: the value of one environment variable of the probe container.
probe_env() {
  jq -r --arg name "$1" '[.spec.template.spec.containers[] | select(.name == "probe") | .env[]? | select(.name == $name) | .value] | first // ""' <<<"$DEPLOYMENT"
}

# The task changes only OTEL_ENABLED and OTEL_EXPORTER_OTLP_ENDPOINT. The
# Deployment probe must stay in outpost with its service name, and its
# TARGET_URL must keep failing: the exceptions it records are the evidence.
check_design_kept() {
  DEPLOYMENT="$(kubectl -n outpost get deployment probe -o json 2>/dev/null)" \
    || fail "Deployment probe is missing in namespace outpost (do not delete or move it)"
  [ "$(probe_env TRACE_SERVICE)" = "probe" ] \
    || fail "TRACE_SERVICE of probe is '$(probe_env TRACE_SERVICE)'; keep it probe"
  [ "$(probe_env TARGET_URL)" = "http://relay.outpost:8080" ] \
    || fail "TARGET_URL of probe is '$(probe_env TARGET_URL)'; keep it http://relay.outpost:8080, its exceptions are the evidence"
}

check_design_kept

endpoint="$(probe_env OTEL_EXPORTER_OTLP_ENDPOINT)"
# Split http://host:port[/] into its parts; any other path breaks /v1/traces.
if [[ "$endpoint" =~ ^http://([^/:]+):([0-9]+)/?$ ]]; then
  host="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[2]}"
else
  fail "OTEL_EXPORTER_OTLP_ENDPOINT of probe is '${endpoint:-not set}'; it must be http://<host>:<port> with no path"
fi
case "$host" in
  jaeger.tracing|jaeger.tracing.svc|jaeger.tracing.svc.cluster.local) ;;
  *) fail "OTEL_EXPORTER_OTLP_ENDPOINT of probe points at '$host', which is not the Service jaeger in namespace tracing" ;;
esac
[ "$port" = "4318" ] || fail "OTEL_EXPORTER_OTLP_ENDPOINT of probe uses port $port; probe sends OTLP over HTTP, which Jaeger receives on 4318"
echo "PASS: probe sends spans to $endpoint"

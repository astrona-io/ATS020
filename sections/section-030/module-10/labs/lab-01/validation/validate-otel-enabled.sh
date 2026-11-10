#!/usr/bin/env bash
# Grader: OpenTelemetry is switched on in the Deployment probe (OTEL_ENABLED
# is "true"), and the rollout that carries the change has finished, so the
# running pod has the new value. The lab starts with "false".
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

value="$(probe_env OTEL_ENABLED)"
[ "$value" = "true" ] || fail "OTEL_ENABLED of probe is '${value:-not set}', expected true"
jq -e '.status.observedGeneration >= .metadata.generation
  and (.status.updatedReplicas // 0) == .spec.replicas
  and (.status.readyReplicas // 0) == .spec.replicas
  and (.status.replicas // 0) == .spec.replicas
  and .spec.replicas == 1' <<<"$DEPLOYMENT" >/dev/null \
  || fail "the rollout of probe has not finished with one ready pod; wait with kubectl -n outpost rollout status deployment/probe"
echo "PASS: OTEL_ENABLED is true and the new probe pod is ready"

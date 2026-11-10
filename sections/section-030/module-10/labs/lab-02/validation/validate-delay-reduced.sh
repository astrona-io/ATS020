#!/usr/bin/env bash
# Grader: the Deployment behind incident.code=retry-storm has the lower delay.
# The span tags and the service name must stay as they were. probe and shuttle
# start with RESPONSE_DELAY_MS=50, so setting 20 on every Deployment fails.
set -euo pipefail
fail() { echo "FAIL: delay-reduced: the Deployment behind incident.code=retry-storm must run with RESPONSE_DELAY_MS=20, one ready replica and its other variables unchanged; probe and shuttle must keep RESPONSE_DELAY_MS=50" >&2; exit 1; }
kubectl -n starfleet rollout status deploy/scout --timeout=90s >/dev/null 2>&1 || fail
kubectl -n starfleet get deploy scout -o json | jq -e '
  .metadata.generation <= .status.observedGeneration and
  .spec.replicas == 1 and .status.updatedReplicas == 1 and .status.readyReplicas == 1 and
  any(.spec.template.spec.containers[];
    .name == "scout" and
    any(.env[]; .name == "RESPONSE_DELAY_MS" and .value == "20") and
    any(.env[]; .name == "TRACE_SERVICE" and .value == "scout") and
    any(.env[]; .name == "INCIDENT_CODE" and .value == "retry-storm"))
' >/dev/null || fail
kubectl -n starfleet get deploy probe shuttle -o json | jq -e '
  all(.items[]; any(.spec.template.spec.containers[].env[]; .name == "RESPONSE_DELAY_MS" and .value == "50"))
' >/dev/null || fail
echo "PASS: delay-reduced"

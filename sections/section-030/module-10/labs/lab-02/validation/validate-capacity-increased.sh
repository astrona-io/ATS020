#!/usr/bin/env bash
# Grader: the Deployment behind incident.code=queue-pressure has more capacity,
# and shuttle, which needs no change, was not scaled with it.
set -euo pipefail
fail() { echo "FAIL: capacity-increased: the Deployment behind incident.code=queue-pressure must have three ready replicas, and shuttle must keep one" >&2; exit 1; }
kubectl -n starfleet rollout status deploy/probe --timeout=90s >/dev/null 2>&1 || fail
kubectl -n starfleet get deploy probe shuttle -o json | jq -e '
  all(.items[];
    (if .metadata.name == "probe" then 3 else 1 end) as $wanted |
    .metadata.generation <= .status.observedGeneration and
    .spec.replicas == $wanted and .status.updatedReplicas == $wanted and
    .status.readyReplicas == $wanted and .status.availableReplicas == $wanted)
' >/dev/null || fail
echo "PASS: capacity-increased"

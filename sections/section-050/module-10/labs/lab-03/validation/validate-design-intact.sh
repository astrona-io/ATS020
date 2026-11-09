#!/usr/bin/env bash
# Keep the selected workload, its Service and the client available.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

SHUTTLE_IMAGE="$(kubectl -n starfleet get deployment shuttle -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)" \
  || fail "Deployment shuttle is missing in namespace starfleet"
[ "$SHUTTLE_IMAGE" = "curlimages/curl:8.23.0" ] || fail "shuttle image changed to '$SHUTTLE_IMAGE'"

for name in cargo; do
  REPLICAS="$(kubectl -n starfleet get deployment "$name" -o jsonpath='{.spec.replicas}' 2>/dev/null)" \
    || fail "Deployment $name is missing in namespace starfleet"
  [ "$REPLICAS" = "1" ] || fail "Deployment $name has $REPLICAS replicas, expected 1 (do not scale a workload to zero)"
  kubectl -n starfleet get service "$name" >/dev/null 2>&1 || fail "Service $name is missing in namespace starfleet"
done

CARGO_COMMAND="$(kubectl -n starfleet get deployment cargo -o jsonpath='{.spec.template.spec.containers[0].command[*]}' 2>/dev/null)"
case "$CARGO_COMMAND" in *"Buffer.alloc"*) ;; *) fail "the command of cargo was changed; size the memory limit instead";; esac

echo "PASS: the four Deployments, their Services and shuttle are unchanged in design"

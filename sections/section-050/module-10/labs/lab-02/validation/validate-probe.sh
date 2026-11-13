#!/usr/bin/env bash
# Grader: probe still has a liveness probe (removing it hides the fault) and
# the probe now passes: the pod is Ready, its restart count does not grow over
# 25 seconds, and shuttle gets a 200 from the Service.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): the workload keeps
# one replica and its Service, and shuttle keeps its image.
SHUTTLE_IMAGE="$(kubectl -n starfleet get deployment shuttle -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)" \
  || fail "Deployment shuttle is missing in namespace starfleet"
[ "$SHUTTLE_IMAGE" = "curlimages/curl:8.23.0" ] || fail "shuttle image changed to '$SHUTTLE_IMAGE'"

for name in probe; do
  REPLICAS="$(kubectl -n starfleet get deployment "$name" -o jsonpath='{.spec.replicas}' 2>/dev/null)" \
    || fail "Deployment $name is missing in namespace starfleet"
  [ "$REPLICAS" = "1" ] || fail "Deployment $name has $REPLICAS replicas, expected 1 (do not scale a workload to zero)"
  kubectl -n starfleet get service "$name" >/dev/null 2>&1 || fail "Service $name is missing in namespace starfleet"
done

IMAGE="$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[?(@.name=="probe")].image}' 2>/dev/null)" \
  || fail "Deployment probe is missing in namespace starfleet (fix it, do not delete it)"
[ "$IMAGE" = "mccutchen/go-httpbin:2.26.0" ] || fail "probe image is '$IMAGE', expected mccutchen/go-httpbin:2.26.0"

PROBE="$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[?(@.name=="probe")].livenessProbe}' 2>/dev/null)"
[ -n "$PROBE" ] || fail "probe has no livenessProbe. Do not remove the probe: point it at a port and path that the server serves"
PORT="$(printf '%s' "$PROBE" | jq -r '.httpGet.port // empty')"
case "$PORT" in
  http|8080) ;;
  *) fail "the liveness probe must reach the server on port 8080 (named http)" ;;
esac

for attempt in $(seq 1 36); do
  READY="$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "${READY:-0}" -ge 1 ] && break
  sleep 5
done
[ "${READY:-0}" -ge 1 ] || fail "probe has no Ready pod"

POD="$(kubectl -n starfleet get pods -l app=probe --field-selector status.phase=Running -o json | jq -r '[.items[] | select(.metadata.deletionTimestamp == null)][0].metadata.name // empty')"
[ -n "$POD" ] || fail "no Running probe pod"
BEFORE="$(kubectl -n starfleet get pod "$POD" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)"
sleep 25
AFTER="$(kubectl -n starfleet get pod "$POD" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)"
[ -n "$AFTER" ] && [ "$BEFORE" = "$AFTER" ] || fail "the probe pod is still restarting (restart count $BEFORE then ${AFTER:-unknown}). Read the Unhealthy events of the pod"

# Give the new probe pod and the Service endpoint a minute to settle.
CODE=""
for attempt in $(seq 1 12); do
  CODE="$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://probe:8080/ 2>/dev/null)"
  [ "$CODE" = "200" ] && break
  sleep 5
done
[ "$CODE" = "200" ] || fail "shuttle got '$CODE' from http://probe:8080/, expected 200"

echo "PASS: probe keeps its liveness probe, is Ready, does not restart and answers 200"

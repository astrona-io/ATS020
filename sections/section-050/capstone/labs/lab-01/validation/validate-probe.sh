#!/usr/bin/env bash
# Grader: probe still has a liveness probe (removing it hides the fault), the
# probe checks the served port 8080, and it now passes: the pod is Ready, its
# restart count does not grow over 25 seconds, and shuttle gets a 200 from the
# Service.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

IMAGE="$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[?(@.name=="probe")].image}' 2>/dev/null)" \
  || fail "Deployment probe is missing in namespace starfleet (fix it, do not delete it)"
[ "$IMAGE" = "mccutchen/go-httpbin:2.25.0" ] || fail "probe image is '$IMAGE', expected mccutchen/go-httpbin:2.25.0"

PROBE="$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[?(@.name=="probe")].livenessProbe}' 2>/dev/null)"
[ -n "$PROBE" ] || fail "probe has no livenessProbe. Do not remove the probe: point it at a port and path that the server serves"
# The server listens only on 8080 (port name http). A probe on any other port
# keeps killing the container, even if the pod looks Ready for a moment.
PROBE_PORT="$(jq -r '.httpGet.port // .tcpSocket.port // empty' <<<"$PROBE")"
case "$PROBE_PORT" in
  8080|http) ;;
  *) fail "the liveness probe of probe checks port '${PROBE_PORT:-none}', but the server listens on 8080 (port name http)" ;;
esac

for attempt in $(seq 1 36); do
  READY="$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "${READY:-0}" -ge 1 ] && break
  sleep 5
done
[ "${READY:-0}" -ge 1 ] || fail "probe has no Ready pod"

POD="$(kubectl -n starfleet get pods -l app=probe --field-selector status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
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

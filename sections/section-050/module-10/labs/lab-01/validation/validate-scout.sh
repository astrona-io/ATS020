#!/usr/bin/env bash
# Grader: scout is no longer Pending. It still runs the original podinfo image,
# it has a Running and Ready pod, and shuttle gets a 200 from the Service.
# Labelling the node or removing the node selector both pass; deleting the
# Deployment or changing the image does not. Retries, because pods start late.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): the workload keeps
# one replica and its Service, and shuttle keeps its image.
SHUTTLE_IMAGE="$(kubectl -n starfleet get deployment shuttle -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)" \
  || fail "Deployment shuttle is missing in namespace starfleet"
[ "$SHUTTLE_IMAGE" = "curlimages/curl:8.23.0" ] || fail "shuttle image changed to '$SHUTTLE_IMAGE'"

for name in scout; do
  REPLICAS="$(kubectl -n starfleet get deployment "$name" -o jsonpath='{.spec.replicas}' 2>/dev/null)" \
    || fail "Deployment $name is missing in namespace starfleet"
  [ "$REPLICAS" = "1" ] || fail "Deployment $name has $REPLICAS replicas, expected 1 (do not scale a workload to zero)"
  kubectl -n starfleet get service "$name" >/dev/null 2>&1 || fail "Service $name is missing in namespace starfleet"
done

IMAGE="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].image}' 2>/dev/null)" \
  || fail "Deployment scout is missing in namespace starfleet (fix it, do not delete it)"
[ "$IMAGE" = "ghcr.io/stefanprodan/podinfo:6.17.0" ] || fail "scout image is '$IMAGE', expected ghcr.io/stefanprodan/podinfo:6.17.0"

for attempt in $(seq 1 36); do
  READY="$(kubectl -n starfleet get deployment scout -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "${READY:-0}" -ge 1 ] && break
  sleep 5
done
[ "${READY:-0}" -ge 1 ] || fail "scout has no Ready pod. Read the events of the Pending pod: kubectl -n starfleet describe pod -l app=scout"

CODE=""
for attempt in $(seq 1 12); do
  CODE="$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://scout:9898/ 2>/dev/null)"
  [ "$CODE" = "200" ] && break
  sleep 5
done
[ "$CODE" = "200" ] || fail "shuttle got '$CODE' from http://scout:9898/, expected 200"

echo "PASS: scout has a Ready pod and answers 200"

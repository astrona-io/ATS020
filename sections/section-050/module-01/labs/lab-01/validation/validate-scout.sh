#!/usr/bin/env bash
# Grader: scout is no longer Pending. It still runs the original podinfo image,
# it has a Running and Ready pod, and shuttle gets a 200 from the Service.
# Labelling the node or removing the node selector both pass; deleting the
# Deployment or changing the image does not. Retries, because pods start late.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

IMAGE="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].image}' 2>/dev/null)" \
  || fail "Deployment scout is missing in namespace starfleet (fix it, do not delete it)"
[ "$IMAGE" = "ghcr.io/stefanprodan/podinfo:6.15.0" ] || fail "scout image is '$IMAGE', expected ghcr.io/stefanprodan/podinfo:6.15.0"

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

#!/usr/bin/env bash
# Grader: beacon runs the pinned image ghcr.io/stefanprodan/podinfo:6.17.0
# (not `latest`), has a Ready pod, and shuttle gets a 200 from the Service.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

IMAGE="$(kubectl -n starfleet get deployment beacon -o jsonpath='{.spec.template.spec.containers[?(@.name=="beacon")].image}' 2>/dev/null)" \
  || fail "Deployment beacon is missing in namespace starfleet (fix it, do not delete it)"
[ "$IMAGE" = "ghcr.io/stefanprodan/podinfo:6.17.0" ] || fail "beacon image is '$IMAGE', expected the existing tag ghcr.io/stefanprodan/podinfo:6.17.0"

for attempt in $(seq 1 36); do
  READY="$(kubectl -n starfleet get deployment beacon -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "${READY:-0}" -ge 1 ] && break
  sleep 5
done
[ "${READY:-0}" -ge 1 ] || fail "beacon has no Ready pod. Read the events of the pod: kubectl -n starfleet describe pod -l app=beacon"

CODE=""
for attempt in $(seq 1 12); do
  CODE="$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://beacon:9898/ 2>/dev/null)"
  [ "$CODE" = "200" ] && break
  sleep 5
done
[ "$CODE" = "200" ] || fail "shuttle got '$CODE' from http://beacon:9898/, expected 200"

echo "PASS: beacon runs podinfo 6.17.0 and answers 200"

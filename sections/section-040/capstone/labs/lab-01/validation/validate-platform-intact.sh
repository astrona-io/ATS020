#!/usr/bin/env bash
# Grader: right-sizing and measuring must not break the platform. The
# Application scout still exists with its ten-entry history and is Healthy,
# scout keeps 3 ready replicas, beacon keeps 1, and a request from shuttle to
# scout returns 200. Deleting or re-syncing the Application, scaling a
# workload down or removing the traffic loop fails here.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

APP="$(kubectl -n argocd get application scout -o json 2>/dev/null)" || fail "the Argo CD Application scout is missing (do not delete it)"
HISTORY="$(printf '%s' "$APP" | jq '.status.history | length')"
[ "$HISTORY" -ge 10 ] || fail "the Application scout has $HISTORY history entries, expected at least 10 (do not recreate it)"
HEALTH="$(printf '%s' "$APP" | jq -r '.status.health.status')"
[ "$HEALTH" = "Healthy" ] || fail "the Application scout is $HEALTH, expected Healthy"

check_deployment() {
  local name="$1" want="$2" json spec ready
  json="$(kubectl -n starfleet get deployment "$name" -o json 2>/dev/null)" || fail "Deployment $name is missing"
  spec="$(printf '%s' "$json" | jq '.spec.replicas')"
  ready="$(printf '%s' "$json" | jq '.status.readyReplicas // 0')"
  [ "$spec" = "$want" ] || fail "Deployment $name has $spec replicas, expected $want"
  [ "$ready" = "$want" ] || fail "Deployment $name has $ready ready replicas, expected $want"
}
check_deployment scout 3
check_deployment beacon 1
check_deployment shuttle 1

CODE=""
for attempt in $(seq 1 12); do
  CODE="$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://scout.starfleet.svc.cluster.local:9898/ 2>/dev/null)"
  [ "$CODE" = "200" ] && break
  sleep 5
done
[ "$CODE" = "200" ] || fail "shuttle gets '${CODE:-no answer}' from scout, expected 200"

echo "PASS: the Application scout is Healthy with $HISTORY history entries, the workloads are ready and scout answers 200"

#!/usr/bin/env bash
# The incident is over only when all services serve requests again. No failed
# request and no new error line may appear in the last minute.
set -u
fail() { echo "FAIL: $*"; exit 1; }

LOKI_API="/api/v1/namespaces/logging/services/loki:3100/proxy/loki/api/v1"
uri() { jq -rn --arg value "$1" '$value | @uri'; }
PROM_API="/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1"

deployments=$(kubectl -n outpost get deployments -o json) || fail "cannot read the Deployments in outpost"
expected=$(echo "$deployments" | jq '.items | length')
[ "$expected" -ge 1 ] || fail "outpost has no Deployments"
echo "$deployments" | jq -e 'all(.items[]; (.status.readyReplicas // 0) >= 1 and (.status.updatedReplicas // 0) == .spec.replicas)' >/dev/null ||
  fail "not every Deployment in outpost has its Pods ready and updated"
kubectl -n starfleet get deployment shuttle -o json | jq -e '(.status.readyReplicas // 0) >= 1' >/dev/null ||
  fail "the Deployment shuttle must keep sending requests"

failed_query='sum(rate(fleet_requests_total{namespace="outpost",status="500"}[1m]))'
failed=$(kubectl get --raw "$PROM_API/query?query=$(uri "$failed_query")" 2>/dev/null | jq -r '.data.result[0].value[1] // "0"')
[ "$failed" = "0" ] || fail "Prometheus still records failed requests in the last minute; if you just made the fix, wait and check again"

serving_query='count(sum by (service) (rate(fleet_requests_total{namespace="outpost",status="200"}[1m])) > 0)'
serving=$(kubectl get --raw "$PROM_API/query?query=$(uri "$serving_query")" 2>/dev/null | jq -r '.data.result[0].value[1] // "0"')
[ "$serving" = "$expected" ] || fail "only $serving of $expected services answered requests successfully in the last minute"

lines_query='sum(count_over_time({namespace="outpost"} |= "ERROR" [1m]))'
lines=$(kubectl get --raw "$LOKI_API/query?query=$(uri "$lines_query")" 2>/dev/null | jq -r '.data.result[0].value[1] // "0"')
[ "$lines" = "0" ] || fail "Loki still receives error lines from outpost; if you just made the fix, wait and check again"
echo "PASS: all services answer, with no failed requests and no new error lines"

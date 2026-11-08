#!/usr/bin/env bash
# Grader: the Deployment grafana in telemetry finished its rollout with one
# ready replica, its Pod is Running, and Grafana's own health endpoint
# reports the database as ok. The endpoint needs no login and is read through
# the API server proxy, so the grader does not need a port-forward.
set -uo pipefail
fail() { echo "FAIL: grafana-ready: $*"; exit 1; }

kubectl -n telemetry get deployment grafana >/dev/null 2>&1 ||
  fail "the Deployment grafana does not exist in the namespace telemetry. Fix it, do not delete it"
[ "$(kubectl -n telemetry get deployment grafana -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "1" ] ||
  fail "the Deployment grafana must keep 1 replica"
kubectl -n telemetry rollout status deployment/grafana --timeout=120s >/dev/null 2>&1 ||
  fail "the Deployment grafana did not finish its rollout. Read 'kubectl -n telemetry describe pod -l app=grafana'"
ready=$(kubectl -n telemetry get deployment grafana -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "${ready:-0}" = "1" ] || fail "the Deployment grafana has ${ready:-0} ready replicas, expected 1"

phase=$(kubectl -n telemetry get pods -l app=grafana -o json 2>/dev/null |
  jq -r '[.items[] | select(.metadata.deletionTimestamp == null)] | .[0].status.phase // ""')
[ "$phase" = "Running" ] || fail "the Grafana Pod is in phase '${phase}', expected Running"

HEALTH="/api/v1/namespaces/telemetry/services/grafana:3000/proxy/api/health"
health=""
for _ in $(seq 1 15); do
  health=$(kubectl get --raw "$HEALTH" 2>/dev/null) && break
  health=""
  sleep 2
done
[ -n "$health" ] || fail "the Service grafana in telemetry does not answer on port 3000"
echo "$health" | jq -e '.database == "ok"' >/dev/null 2>&1 ||
  fail "Grafana answers, but /api/health does not report the database as ok: ${health}"
echo "PASS: grafana-ready: the Deployment grafana runs in telemetry and its database is ok"

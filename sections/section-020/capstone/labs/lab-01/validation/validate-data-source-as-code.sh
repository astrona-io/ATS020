#!/usr/bin/env bash
# Grades that the fix stays "as code": every data source UID the panels use must
# exist in Grafana and be read-only, which Grafana reports for provisioned data
# sources. A data source created by hand in the web interface is editable and
# would be lost when the pod is replaced.
set -u
fail() { echo "FAIL: $*"; exit 1; }

# Grafana has no auth through the API server proxy, so use a port-forward.
GRAFANA_PORT=$((13300 + RANDOM % 500))
GRAFANA="http://127.0.0.1:${GRAFANA_PORT}"
kubectl -n monitoring port-forward svc/kps-grafana "${GRAFANA_PORT}:80" >/dev/null 2>&1 &
FORWARD_PID=$!
trap 'kill "$FORWARD_PID" 2>/dev/null' EXIT
for _ in $(seq 1 30); do
  curl -fsS "$GRAFANA/api/health" >/dev/null 2>&1 && break
  sleep 2
done
grafana_get() { curl -fsS -u admin:starfleet "$GRAFANA$1" 2>/dev/null; }

dashboard=$(grafana_get /api/dashboards/uid/outpost-overview) || fail "Grafana has no dashboard with the UID outpost-overview"
uids=$(echo "$dashboard" | jq -r '[.dashboard.panels[] | (.datasource.uid // empty), (.targets[]? | .datasource.uid // empty)] | unique | .[]')
[[ -n "$uids" ]] || fail "no panel names a data source UID"
for uid in $uids; do
  source_json=$(grafana_get "/api/datasources/uid/$uid") || fail "no data source has the UID '$uid'"
  [[ "$(echo "$source_json" | jq -r '.readOnly')" == "true" ]] ||
    fail "the data source '$uid' is not provisioned (it is not read-only); keep the data source in its ConfigMap"
done
echo "PASS: the data sources used by the panels are provisioned"

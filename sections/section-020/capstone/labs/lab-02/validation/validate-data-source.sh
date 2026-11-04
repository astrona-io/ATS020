#!/usr/bin/env bash
# The Loki data source exists with its address and Maximum lines, stays editable
# and passes Grafana's health check. The web interface stores
# jsonData.maxLines as a string and an API client may send a number.
set -u
fail() { echo "FAIL: $*"; exit 1; }

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

source_json=$(grafana_get /api/datasources/uid/loki) || fail "Grafana has no data source with the UID loki"
echo "$source_json" | jq -e '.type == "loki"' >/dev/null || fail "the data source with the UID loki is not of type loki"
echo "$source_json" | jq -e '.name == "Loki"' >/dev/null || fail "the data source must be named Loki"
echo "$source_json" | jq -e '.url == "http://loki.logging:3100"' >/dev/null || fail "the data source address must be http://loki.logging:3100"
echo "$source_json" | jq -e '.readOnly != true' >/dev/null || fail "create the data source in Grafana, not from a provisioning file"
echo "$source_json" | jq -e '(.jsonData.maxLines? | tonumber? // 0) == 500' >/dev/null || fail "Maximum lines is not 500"
grafana_get /api/datasources/uid/loki/health >/dev/null || fail "the health check of the Loki data source fails"
echo "PASS: the Loki data source is healthy and has Maximum lines set to 500"

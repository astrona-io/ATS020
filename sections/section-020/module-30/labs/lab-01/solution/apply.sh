#!/usr/bin/env bash
# Reference solution for `astrona test`.
set -euo pipefail

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
LOKI_API="/api/v1/namespaces/logging/services/loki:3100/proxy/loki/api/v1"
uri() { jq -rn --arg value "$1" '$value | @uri'; }
grafana() { curl -fsS -u admin:starfleet -H 'Content-Type: application/json' "$@"; }

grafana_get /api/datasources/uid/loki | jq '.jsonData.maxLines = 250' |
  grafana -X PUT "$GRAFANA/api/datasources/uid/loki" -d @- >/dev/null

grafana_get /api/dashboards/uid/outpost-logs | jq '
  {
    dashboard: (.dashboard
      | (.panels[] | select(.title == "Error lines") | .targets[0].expr) = "{namespace=\"outpost\"} |= \"ERROR\""
      | (.panels[] | select(.title == "Streams with errors") | .targets[0].expr) = "count(rate({namespace=\"outpost\"} |= \"ERROR\" [5m]))"),
    overwrite: false,
    message: "Show outpost errors"
  }' | grafana -X POST "$GRAFANA/api/dashboards/db" -d @- >/dev/null

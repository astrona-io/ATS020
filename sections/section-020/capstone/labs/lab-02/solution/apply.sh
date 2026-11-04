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
PROM_API="/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1"
grafana() { curl -fsS -u admin:starfleet -H 'Content-Type: application/json' "$@"; }

jq -n '{name: "Loki", uid: "loki", type: "loki", access: "proxy", url: "http://loki.logging:3100", jsonData: {maxLines: 500}}' |
  grafana -X POST "$GRAFANA/api/datasources/" -d @- >/dev/null

grafana_get /api/dashboards/uid/incident-overview | jq '
  {
    dashboard: (.dashboard
      | (.panels[] | select(.title == "Failed requests") | .targets[0].expr) = "sum by (service) (rate(fleet_requests_total{namespace=\"outpost\",status=\"500\"}[5m]))"
      | (.panels[] | select(.title == "Error lines") | .targets[0].expr) = "{namespace=\"outpost\"} |= \"ERROR\""),
    overwrite: false,
    message: "Show the incident"
  }' | grafana -X POST "$GRAFANA/api/dashboards/db" -d @- >/dev/null

# Wait for evidence in both backends before reading the answers from them.
failed_query='sum by (service) (increase(fleet_requests_total{namespace="outpost",status="500"}[2h]))'
line_query='{namespace="outpost"} |= "ERROR"'
service=""
store_path=""
for _ in $(seq 1 60); do
  service=$(kubectl get --raw "$PROM_API/query?query=$(uri "$failed_query")" 2>/dev/null |
    jq -r '[.data.result[] | select((.value[1] | tonumber) > 0) | .metric.service] | first // ""' || true)
  store_path=$(kubectl get --raw "$LOKI_API/query_range?query=$(uri "$line_query")&since=6h&limit=50" 2>/dev/null |
    jq -r '[.data.result[].values[][1] | capture("path=(?<value>[^ ]+)") | .value] | first // ""' || true)
  [ -n "$service" ] && [ -n "$store_path" ] && break
  sleep 5
done
[ -n "$service" ] && [ -n "$store_path" ] || { echo "Prometheus or Loki did not receive the evidence in time" >&2; exit 1; }
printf '%s\n' "$service" > /tmp/ats-020-incident-service.txt
printf '%s\n' "$store_path" > /tmp/ats-020-incident-path.txt

kubectl -n outpost set env "deployment/$service" STORE_PATH=/data/store
kubectl -n outpost rollout status "deployment/$service" --timeout=180s

# The one-minute checks only clear after the old Pod's samples leave the window.
failed_now='sum(rate(fleet_requests_total{namespace="outpost",status="500"}[1m]))'
lines_now='sum(count_over_time({namespace="outpost"} |= "ERROR" [1m]))'
serving_now='count(sum by (service) (rate(fleet_requests_total{namespace="outpost",status="200"}[1m])) > 0)'
for _ in $(seq 1 60); do
  failed=$(kubectl get --raw "$PROM_API/query?query=$(uri "$failed_now")" 2>/dev/null | jq -r '.data.result[0].value[1] // "0"' || echo 1)
  lines=$(kubectl get --raw "$LOKI_API/query?query=$(uri "$lines_now")" 2>/dev/null | jq -r '.data.result[0].value[1] // "0"' || echo 1)
  serving=$(kubectl get --raw "$PROM_API/query?query=$(uri "$serving_now")" 2>/dev/null | jq -r '.data.result[0].value[1] // "0"' || echo 0)
  [ "$failed" = "0" ] && [ "$lines" = "0" ] && [ "$serving" = "3" ] && exit 0
  sleep 5
done
echo "The incident did not clear in time" >&2
exit 1

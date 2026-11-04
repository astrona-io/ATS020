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

# Wait until Loki holds ERROR lines from every Pod that writes them, including
# probe, which logs ERROR only for the failing requests from shuttle.
query='sum by (pod) (count_over_time({namespace="outpost"} |= "ERROR" [6h]))'
ready=""
for _ in $(seq 1 60); do
  pods=$(kubectl get --raw "$LOKI_API/query?query=$(uri "$query")" 2>/dev/null | jq -r '.data.result[].metric.pod' || true)
  probes=$(grep -c '^probe-' <<< "$pods" || true)
  cargos=$(grep -c '^cargo-' <<< "$pods" || true)
  if [ "$probes" -ge 2 ] && [ "$cargos" -ge 2 ]; then
    ready=yes
    break
  fi
  sleep 5
done
[ -n "$ready" ] || { echo "Loki did not receive the ERROR lines in time" >&2; exit 1; }

kubectl -n outpost scale deployment/probe --replicas=0
kubectl -n outpost scale statefulset/cargo --replicas=0
kubectl -n outpost wait --for=delete pod -l app=probe --timeout=120s
kubectl -n outpost wait --for=delete pod -l app=cargo --timeout=120s

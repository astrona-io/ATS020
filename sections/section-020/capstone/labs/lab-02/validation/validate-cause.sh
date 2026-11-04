#!/usr/bin/env bash
# Compares the two answer files with what Prometheus and Loki recorded.
set -u
fail() { echo "FAIL: $*"; exit 1; }

LOKI_API="/api/v1/namespaces/logging/services/loki:3100/proxy/loki/api/v1"
uri() { jq -rn --arg value "$1" '$value | @uri'; }
PROM_API="/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1"
SERVICE_FILE=/tmp/ats-020-incident-service.txt
PATH_FILE=/tmp/ats-020-incident-path.txt

[ -s "$SERVICE_FILE" ] || fail "$SERVICE_FILE is missing or empty"
[ -s "$PATH_FILE" ] || fail "$PATH_FILE is missing or empty"

query='topk(1, sum by (service) (increase(fleet_requests_total{namespace="outpost",status="500"}[2h])))'
expected_service=$(kubectl get --raw "$PROM_API/query?query=$(uri "$query")" 2>/dev/null |
  jq -r '[.data.result[] | select((.value[1] | tonumber) > 0) | .metric.service] | first // ""')
[ -n "$expected_service" ] || fail "Prometheus holds no failed requests to compare with"
[ "$(tr -d '[:space:]' < "$SERVICE_FILE")" = "$expected_service" ] ||
  fail "$SERVICE_FILE does not name the Deployment with the failed requests"

line_query='{namespace="outpost"} |= "ERROR"'
expected_path=$(kubectl get --raw "$LOKI_API/query_range?query=$(uri "$line_query")&since=6h&limit=50&direction=forward" 2>/dev/null |
  jq -r '[.data.result[].values[][1] | capture("path=(?<value>[^ ]+)") | .value] | first // ""')
[ -n "$expected_path" ] || fail "Loki holds no error line to compare with"
[ "$(tr -d '[:space:]' < "$PATH_FILE")" = "$expected_path" ] ||
  fail "$PATH_FILE does not hold the path from the error lines"
echo "PASS: both answer files match what Prometheus and Loki recorded"

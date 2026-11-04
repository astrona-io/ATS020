#!/usr/bin/env bash
# Runs the saved queries of both panels over the recent past, because the failed
# requests and error lines stop once the incident is fixed.
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
LOKI_API="/api/v1/namespaces/logging/services/loki:3100/proxy/loki/api/v1"
uri() { jq -rn --arg value "$1" '$value | @uri'; }
PROM_API="/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1"

dashboard=$(grafana_get /api/dashboards/uid/incident-overview) || fail "Grafana has no dashboard with the UID incident-overview"
echo "$dashboard" | jq -e '.meta.provisioned != true' >/dev/null || fail "keep the saved dashboard; do not replace it with a provisioned one"

panel_query() {
  echo "$dashboard" | jq -c --arg title "$1" \
    '[.dashboard | .. | objects | select(.title? == $title) | .. | objects | select(has("expr"))] | first // {}'
}

metric_query=$(panel_query "Failed requests")
metric_expr=$(echo "$metric_query" | jq -r '.expr // ""')
[ -n "$metric_expr" ] || fail "the panel 'Failed requests' has no query"
echo "$metric_query" | jq -e '(.datasource.uid // "prometheus") == "prometheus"' >/dev/null || fail "the panel 'Failed requests' must use the Prometheus data source"
compact=$(printf '%s' "$metric_expr" | tr -d '[:space:]')
case "$compact" in *'namespace="outpost"'*) ;; *) fail "the panel 'Failed requests' must select the outpost namespace" ;; esac
case "$compact" in *'status="500"'*) ;; *) fail "the panel 'Failed requests' must select failed requests" ;; esac
now=$(date -u +%s)
metric_result=$(kubectl get --raw "$PROM_API/query_range?query=$(uri "$metric_expr")&start=$((now - 7200))&end=$now&step=60" 2>/dev/null) ||
  fail "Prometheus refuses the query of the panel 'Failed requests'"
echo "$metric_result" | jq -e 'all(.data.result[]; .metric.service != null) and (.data.result | length >= 1)' >/dev/null ||
  fail "the panel 'Failed requests' must show one series per service"
echo "$metric_result" | jq -e 'any(.data.result[].values[]; (.[1] | tonumber) > 0)' >/dev/null ||
  fail "the query of the panel 'Failed requests' shows no failures"

log_query=$(panel_query "Error lines")
log_expr=$(echo "$log_query" | jq -r '.expr // ""')
[ -n "$log_expr" ] || fail "the panel 'Error lines' has no query"
echo "$log_query" | jq -e '(.datasource.uid // "loki") == "loki"' >/dev/null || fail "the panel 'Error lines' must use the Loki data source"
log_result=$(kubectl get --raw "$LOKI_API/query_range?query=$(uri "$log_expr")&since=6h&limit=200" 2>/dev/null) ||
  fail "Loki refuses the query of the panel 'Error lines'"
echo "$log_result" | jq -e '.data.resultType == "streams"' >/dev/null || fail "the panel 'Error lines' must be a log query"
echo "$log_result" | jq -e '[.data.result[].values[]] | length >= 1' >/dev/null || fail "the query of the panel 'Error lines' returns no lines"
echo "$log_result" | jq -e 'all(.data.result[]; .stream.namespace == "outpost")' >/dev/null || fail "the panel 'Error lines' shows streams from outside outpost"
echo "$log_result" | jq -e 'all(.data.result[].values[]; .[1] | contains("ERROR"))' >/dev/null || fail "the panel 'Error lines' shows lines without ERROR"
echo "PASS: both panels show the incident through their own data sources"

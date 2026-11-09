#!/usr/bin/env bash
# Run the saved panel queries against the live Loki data.
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

dashboard=$(grafana_get /api/dashboards/uid/outpost-logs) || fail "Grafana has no dashboard with the UID outpost-logs"
echo "$dashboard" | jq -e '.meta.provisioned != true' >/dev/null || fail "keep the saved dashboard; do not replace it with a provisioned one"

panel_expr() {
  echo "$dashboard" | jq -r --arg title "$1" \
    '[.dashboard | .. | objects | select(.title? == $title) | .. | objects | .expr? // empty] | first // ""'
}

log_expr=$(panel_expr "Error lines")
[ -n "$log_expr" ] || fail "the panel 'Error lines' has no query"
log_result=$(kubectl get --raw "$LOKI_API/query_range?query=$(uri "$log_expr")&since=6h&limit=200" 2>/dev/null) ||
  fail "Loki refuses the query of the panel 'Error lines'"
echo "$log_result" | jq -e '.data.resultType == "streams"' >/dev/null || fail "the panel 'Error lines' must be a log query, not a metric query"
echo "$log_result" | jq -e '[.data.result[].values[]] | length >= 1' >/dev/null || fail "the query of the panel 'Error lines' returns no lines"
echo "$log_result" | jq -e 'all(.data.result[]; .stream.namespace == "outpost")' >/dev/null || fail "the panel 'Error lines' shows streams from outside outpost"
echo "$log_result" | jq -e 'all(.data.result[].values[]; .[1] | contains("ERROR"))' >/dev/null || fail "the panel 'Error lines' shows lines without ERROR"

metric_expr=$(panel_expr "Streams with errors")
[ -n "$metric_expr" ] || fail "the panel 'Streams with errors' has no query"
compact=$(printf '%s' "$metric_expr" | tr -d '[:space:]')
case "$compact" in
  count\(rate\(*\)\)) ;;
  *) fail "the panel 'Streams with errors' must count a rate: count(rate(...))" ;;
esac
case "$compact" in *'namespace="outpost"'*) ;; *) fail "the panel 'Streams with errors' must select the outpost namespace" ;; esac
case "$compact" in *'|="ERROR"'*) ;; *) fail "the panel 'Streams with errors' must filter on ERROR" ;; esac
case "$compact" in *'[5m]'*) ;; *) fail "the panel 'Streams with errors' must use a five-minute range" ;; esac
metric_result=$(kubectl get --raw "$LOKI_API/query?query=$(uri "$metric_expr")" 2>/dev/null) ||
  fail "Loki refuses the query of the panel 'Streams with errors'"
echo "$metric_result" | jq -e '.data.resultType == "vector" and any(.data.result[]; (.["value"][1] | tonumber) > 0)' >/dev/null ||
  fail "the query of the panel 'Streams with errors' returns no data"
echo "PASS: both panels hold queries that return the outpost errors"

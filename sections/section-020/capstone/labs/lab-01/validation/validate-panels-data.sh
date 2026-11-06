#!/usr/bin/env bash
# Grades the behaviour: the dashboard must still have its three panels, and the
# query of every panel must return data when Grafana sends it to the data source
# the panel names. Deleting panels or pointing them at a missing data source
# fails. All three queries return series once the Collector counts the probe errors.
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

dashboard=""
for _ in $(seq 1 36); do
  dashboard=$(grafana_get /api/dashboards/uid/outpost-overview) && [[ -n "$dashboard" ]] && break
  sleep 5
done
[[ -n "$dashboard" ]] || fail "Grafana has no dashboard with the UID outpost-overview"

for title in "Request rate" "Error ratio" "Error log lines"; do
  echo "$dashboard" | jq -e --arg t "$title" '[.dashboard.panels[] | select(.title==$t)] | length == 1' >/dev/null ||
    fail "the panel '$title' is missing; fix the dashboard, do not delete panels"
done

echo "$dashboard" | jq -e '[.dashboard.panels[] | select(.title=="Error log lines") | .targets[].expr | select(contains("log_error_lines_total"))] | length >= 1' >/dev/null ||
  fail "the panel 'Error log lines' must query the metric log_error_lines_total made from the logs"

checked=0
while IFS=$'\t' read -r title uid expr; do
  expr=${expr//\$namespace/outpost}
  ok=""
  for _ in $(seq 1 24); do
    body=$(jq -n --arg uid "$uid" --arg expr "$expr" \
      '{from: "now-5m", to: "now", queries: [{refId: "A", datasource: {uid: $uid}, expr: $expr, instant: true}]}')
    values=$(curl -s -u admin:starfleet -H 'Content-Type: application/json' "$GRAFANA/api/ds/query" -d "$body" |
      jq -r '[.results.A.frames[]?.data.values[1][0]? | select(. != null)] | length')
    [[ "${values:-0}" -ge 1 ]] && { ok=yes; break; }
    sleep 5
  done
  [[ -n "$ok" ]] || fail "the panel '$title' returns no data through the data source UID '$uid'"
  checked=$((checked+1))
done < <(echo "$dashboard" | jq -r '.dashboard.panels[] | .title as $t | (.datasource.uid // "") as $panel_uid | .targets[] | [$t, ((.datasource.uid // $panel_uid)), .expr] | @tsv')
[[ "$checked" -ge 3 ]] || fail "only $checked panel queries found, expected at least 3"
echo "PASS: all $checked panel queries return data"

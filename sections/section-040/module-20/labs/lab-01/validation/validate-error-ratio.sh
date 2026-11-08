#!/usr/bin/env bash
# Grader: both recording rules return the real error ratio of scout. The
# traffic loop makes 1 of every 20 requests to scout fail, so the ratio is
# about 0.05. It must be above 0.03 and below 0.08 for the 5 minute and the
# 1 hour rule. No data (the faulty rule), 0 and 1 all fail. The expressions
# must read the request counter, with no typed-in number as the ratio.
# Retries, because a changed rule reaches Prometheus after about 60 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

query() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$1" 2>/dev/null
}

RULE="$(kubectl -n monitoring get prometheusrule scout-slo -o json 2>/dev/null)" \
  || fail "PrometheusRule scout-slo is missing in namespace monitoring"

for record in scout:error_ratio:rate5m scout:error_ratio:rate1h; do
  EXPR="$(printf '%s' "$RULE" | jq -r --arg r "$record" '[.spec.groups[].rules[] | select(.record == $r)][0].expr // ""')"
  case "$EXPR" in *http_requests_total*) ;; *) fail "$record does not read http_requests_total: '$EXPR'" ;; esac
  case "$EXPR" in *vector\(*) fail "$record uses vector(): '$EXPR' (the ratio must come from the counter)" ;; esac
done

for record in scout:error_ratio:rate5m scout:error_ratio:rate1h; do
  VALUE=""
  OK=0
  for attempt in $(seq 1 36); do
    VALUE="$(query "$record" | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
    if [ -n "$VALUE" ] && awk -v v="$VALUE" 'BEGIN {exit !(v > 0.03 && v < 0.08)}'; then
      OK=1
      break
    fi
    sleep 5
  done
  [ "$OK" = "1" ] || fail "$record is '${VALUE:-no data}', expected a value between 0.03 and 0.08 (1 of every 20 requests fails)"
  echo "PASS: $record is $VALUE"
done

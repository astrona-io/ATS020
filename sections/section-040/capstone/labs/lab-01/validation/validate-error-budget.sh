#!/usr/bin/env bash
# Grader: the series scout:error_budget_remaining:ratio1h is the remaining
# error budget of a 99% SLO over one hour. The traffic loop makes 1 of every
# 20 requests to scout fail, an error ratio of 0.05 against a budget of 0.01,
# so the value is about -4. It must be between -6 and -2.5. A value of 1 (no
# errors seen), 0 and a budget that was computed from the wrong selector all
# fail. The loaded rule must read the request counter and not use vector().
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

prom() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1" 2>/dev/null
}

VALUE=""
for attempt in $(seq 1 36); do
  VALUE="$(prom 'query?query=scout:error_budget_remaining:ratio1h' | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ -n "$VALUE" ] && awk -v v="$VALUE" 'BEGIN {exit !(v > -6 && v < -2.5)}'; then
    break
  fi
  sleep 5
done
[ -n "$VALUE" ] || fail "the series scout:error_budget_remaining:ratio1h has no data"
awk -v v="$VALUE" 'BEGIN {exit !(v > -6 && v < -2.5)}' \
  || fail "scout:error_budget_remaining:ratio1h is $VALUE, expected about -4 (5% errors against a 1% budget)"

ALL="$(prom 'rules?type=record' | jq -r '[.data.groups[].rules[] | select(.name | startswith("scout:")) | .query] | join(" ")' | tr -d ' ')"
case "$ALL" in *http_requests_total*) ;; *) fail "no scout: rule reads http_requests_total";; esac
case "$ALL" in *vector\(*) fail "a scout: rule uses vector(); the budget must come from the counter";; esac

echo "PASS: scout:error_budget_remaining:ratio1h is $VALUE"

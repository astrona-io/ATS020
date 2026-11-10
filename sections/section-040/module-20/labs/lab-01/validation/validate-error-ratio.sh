#!/usr/bin/env bash
# Grader: both recording rules return the real error ratio of scout. The
# traffic loop makes 1 of every 20 requests to scout fail, so the ratio is
# about 0.05. It must be above 0.03 and below 0.08 for the 5 minute and the
# 1 hour rule. No data (the faulty rule), 0 and 1 all fail. The expressions
# must read the request counter, with no typed-in number as the ratio.
# Retries, because a changed rule reaches Prometheus after about 60 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): the PrometheusRule
# scout-slo keeps its two recording rules and its multi-window alert with a
# real.
RULE="$(kubectl -n monitoring get prometheusrule scout-slo -o json 2>/dev/null)" \
  || fail "PrometheusRule scout-slo is missing in namespace monitoring (do not delete it)"

LABEL="$(printf '%s' "$RULE" | jq -r '.metadata.labels.release // ""')"
[ "$LABEL" = "kps" ] || fail "PrometheusRule scout-slo has release='$LABEL'; Prometheus only reads rules labelled release=kps"

for record in scout:error_ratio:rate5m scout:error_ratio:rate1h; do
  printf '%s' "$RULE" | jq -e --arg r "$record" '[.spec.groups[].rules[] | select(.record == $r)] | length == 1' >/dev/null \
    || fail "the recording rule $record is missing (keep both recording rules)"
done

ALERT="$(printf '%s' "$RULE" | jq -c '[.spec.groups[].rules[] | select(.alert == "ScoutErrorBudgetBurn")][0] // empty')"
[ -n "$ALERT" ] || fail "the alerting rule ScoutErrorBudgetBurn is missing (do not delete it)"

EXPR="$(printf '%s' "$ALERT" | jq -r '.expr' | tr -d ' ')"
case "$EXPR" in *5m*) ;; *) fail "the alert no longer reads the 5 minute window: '$EXPR'" ;; esac
case "$EXPR" in *1h*) ;; *) fail "the alert no longer reads the 1 hour window: '$EXPR'" ;; esac
case "$EXPR" in *and*) ;; *) fail "the alert must require both windows with 'and': '$EXPR'" ;; esac
if printf '%s' "$EXPR" | grep -Eq '>0(\.0*)?(and|$|\))'; then
  fail "the alert threshold is zero; a burn rate threshold of 0 fires on a single failed request"
fi

FOR="$(printf '%s' "$ALERT" | jq -r '.for // ""')"
case "$FOR" in
  *s) SECONDS_FOR="${FOR%s}" ;;
  *m) SECONDS_FOR="$(( ${FOR%m} * 60 ))" ;;
  *) fail "the alert has no 'for' value (or one in an unknown unit: '$FOR')" ;;
esac
[ "$SECONDS_FOR" -ge 1 ] || fail "the alert needs a 'for' value, for example 2m"
[ "$SECONDS_FOR" -le 300 ] || fail "the alert 'for' is $FOR; keep it at 5m or less"

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

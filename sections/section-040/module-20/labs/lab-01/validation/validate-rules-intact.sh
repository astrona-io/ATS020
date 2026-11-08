#!/usr/bin/env bash
# Grader: the fix keeps the design. The PrometheusRule scout-slo still exists
# in monitoring with the label Prometheus selects (release: kps). Both
# recording rules and the alert ScoutErrorBudgetBurn still exist. The alert
# keeps both windows (5m and 1h) joined with `and`, has a short `for` (at most
# 5 minutes) and a threshold that is not zero. Deleting the rule, deleting a
# window or lowering the threshold to zero does not pass.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

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

echo "PASS: scout-slo keeps both recording rules and a multi-window alert (for: $FOR)"

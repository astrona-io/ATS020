#!/usr/bin/env bash
# Grader: the alert ScoutErrorBudgetBurn is loaded in Prometheus, joins a 5
# minute window and a 1 hour window with `and`, has a threshold that is not
# zero, has a short `for` (1 second to 5 minutes) and is in the state firing
# (scout burns its budget at about 5 times the allowed speed). The alert waits
# for its `for` time after the rule reaches Prometheus (about 60 seconds), so
# the state check retries for up to 8 minutes.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

prom() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1" 2>/dev/null
}

RULE=""
for attempt in $(seq 1 24); do
  RULE="$(prom 'rules?type=alert' | jq -c '[.data.groups[].rules[] | select(.name == "ScoutErrorBudgetBurn")][0] // empty' 2>/dev/null)"
  [ -n "$RULE" ] && break
  sleep 5
done
[ -n "$RULE" ] || fail "Prometheus has no loaded alert named ScoutErrorBudgetBurn"

EXPR="$(printf '%s' "$RULE" | jq -r '.query' | tr -d ' ')"
# The alert may read the windows directly or through recording rules.
ALL="$EXPR $(prom 'rules?type=record' | jq -r '[.data.groups[].rules[] | .name + "=" + .query] | join(" ")' | tr -d ' ')"
case "$EXPR" in *and*) ;; *) fail "the alert must require both windows with 'and': '$EXPR'";; esac
case "$ALL" in *5m*) ;; *) fail "no 5 minute window in the alert or in the rules it reads";; esac
case "$ALL" in *1h*) ;; *) fail "no 1 hour window in the alert or in the rules it reads";; esac
if printf '%s' "$EXPR" | grep -Eq '>0(\.0*)?(and|$|\))'; then
  fail "the alert threshold is zero; a burn rate threshold of 0 fires on a single failed request"
fi
case "$EXPR" in *\>*) ;; *) fail "the alert expression has no threshold: '$EXPR'";; esac

FOR="$(printf '%s' "$RULE" | jq -r '.duration // 0')"
awk -v f="$FOR" 'BEGIN {exit !(f >= 1 && f <= 300)}' \
  || fail "the alert 'for' is ${FOR}s; it must be at least 1 second and at most 5 minutes"

STATE=""
for attempt in $(seq 1 96); do
  STATE="$(prom 'alerts' | jq -r '[.data.alerts[] | select(.labels.alertname == "ScoutErrorBudgetBurn")][0].state // empty' 2>/dev/null)"
  if [ "$STATE" = "firing" ]; then
    echo "PASS: ScoutErrorBudgetBurn has two windows, for ${FOR}s, and is firing"
    exit 0
  fi
  sleep 5
done
fail "ScoutErrorBudgetBurn is '${STATE:-not active}', expected firing (scout fails 5% of its requests, a burn rate of about 5)"

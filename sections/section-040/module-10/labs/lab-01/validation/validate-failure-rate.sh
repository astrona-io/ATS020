#!/usr/bin/env bash
# Grader: Prometheus returns the change failure rate that the delivery
# history holds. Two deployments went Degraded. increase() counts eight or
# nine of the ten syncs (it depends on the first scrape and on extrapolation),
# so the ratio is 0.25 or 0.22. It must be above 0.15 and below 0.30; a third
# Degraded episode (0.33 or more) fails on purpose. Zero (the faulty
# rule) and one (a rule that counts everything) both fail. Retries, because a
# changed rule reaches Prometheus after about 60 seconds and is then
# evaluated every 15 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): the PrometheusRule
# dora-scout still has its three recording rules and the deployments rule is
# unchanged.
RULE="$(kubectl -n monitoring get prometheusrule dora-scout -o json 2>/dev/null)" \
  || fail "PrometheusRule dora-scout is missing in namespace monitoring (do not delete it)"

LABEL="$(printf '%s' "$RULE" | jq -r '.metadata.labels.release // ""')"
[ "$LABEL" = "kps" ] || fail "PrometheusRule dora-scout has release='$LABEL'; Prometheus only reads rules labelled release=kps"

for record in dora:deployments:increase6h dora:failed_deployments:count6h dora:change_failure_rate:ratio6h; do
  printf '%s' "$RULE" | jq -e --arg r "$record" '[.spec.groups[].rules[] | select(.record == $r)] | length == 1' >/dev/null \
    || fail "the recording rule $record is missing (keep all three rules)"
done

DEPLOYMENTS="$(printf '%s' "$RULE" | jq -r '.spec.groups[].rules[] | select(.record == "dora:deployments:increase6h") | .expr' | tr -d ' ')"
EXPECTED='round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))'
[ "$DEPLOYMENTS" = "$EXPECTED" ] || fail "the deployments rule changed: '$DEPLOYMENTS' (it was already correct, leave it alone)"

query() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$1" 2>/dev/null
}

VALUE=""
for attempt in $(seq 1 36); do
  VALUE="$(query 'dora:change_failure_rate:ratio6h' | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ -n "$VALUE" ] && awk -v v="$VALUE" 'BEGIN {exit !(v > 0.15 && v < 0.30)}'; then
    echo "PASS: dora:change_failure_rate:ratio6h is $VALUE"
    exit 0
  fi
  sleep 5
done
fail "dora:change_failure_rate:ratio6h is '${VALUE:-no data}', expected a value between 0.15 and 0.30 (two failed deployments out of eight to ten counted ones)"

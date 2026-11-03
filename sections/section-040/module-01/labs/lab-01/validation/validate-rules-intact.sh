#!/usr/bin/env bash
# Grader: the fix keeps the design. The PrometheusRule dora-scout still exists
# in monitoring with the label Prometheus selects (release: kps), the
# deployment count rule is unchanged and still reads the sync counter, and
# the three recording rules still exist. Deleting a rule does not pass.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

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

echo "PASS: dora-scout keeps its three recording rules and the deployments rule is unchanged"

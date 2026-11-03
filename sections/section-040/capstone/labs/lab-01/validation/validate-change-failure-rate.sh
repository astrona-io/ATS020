#!/usr/bin/env bash
# Grader: the series dora:change_failure_rate:ratio6h returns the real change
# failure rate of scout: two failed deployments out of nine counted ones, so
# about 0.22. It must be above 0.15 and below 0.30. Zero (a rule that counts
# failed sync phases) and one both fail. The loaded rules that make the rate
# must read the Degraded health from argocd_app_info, must not rely on the
# sync phases Failed or Error and must not use vector().
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

prom() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1" 2>/dev/null
}

VALUE=""
for attempt in $(seq 1 36); do
  VALUE="$(prom 'query?query=dora:change_failure_rate:ratio6h' | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ -n "$VALUE" ] && awk -v v="$VALUE" 'BEGIN {exit !(v > 0.15 && v < 0.30)}'; then
    break
  fi
  sleep 5
done
[ -n "$VALUE" ] || fail "the series dora:change_failure_rate:ratio6h has no data"
awk -v v="$VALUE" 'BEGIN {exit !(v > 0.15 && v < 0.30)}' \
  || fail "dora:change_failure_rate:ratio6h is $VALUE, expected a value between 0.15 and 0.30 (two failed deployments out of nine)"

ALL="$(prom 'rules?type=record' | jq -r '[.data.groups[].rules[] | select(.name | startswith("dora:")) | .query] | join(" ")' | tr -d ' ')"
case "$ALL" in *argocd_app_info*) ;; *) fail "no dora: rule reads argocd_app_info";; esac
case "$ALL" in *health_status=\"Degraded\"*|*health_status=~\"*Degraded*\"*) ;; *) fail "no dora: rule looks at health_status=\"Degraded\"";; esac
case "$ALL" in *vector\(*) fail "a dora: rule uses vector(); a typed-in number does not measure anything";; esac
case "$ALL" in *phase=~\"*Failed*\"*|*phase=\"Failed\"*|*phase=\"Error\"*) fail "a dora: rule counts the sync phases Failed or Error, which Argo CD never records for a bad image tag";; esac

echo "PASS: dora:change_failure_rate:ratio6h is $VALUE and comes from the Degraded health"

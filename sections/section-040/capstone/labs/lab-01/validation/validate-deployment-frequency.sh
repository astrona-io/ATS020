#!/usr/bin/env bash
# Grader: the series dora:deployments:increase6h counts the deployments of
# the Application scout. Argo CD synced ten times and increase() sees nine of
# them, so the value must be between 8 and 11. The loaded rule must read the
# sync counter and must not hold a typed-in number. Retries, because a new
# rule reaches Prometheus after about 60 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

prom() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1" 2>/dev/null
}

VALUE=""
for attempt in $(seq 1 36); do
  VALUE="$(prom 'query?query=dora:deployments:increase6h' | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ -n "$VALUE" ] && awk -v v="$VALUE" 'BEGIN {exit !(v >= 8 && v <= 11)}'; then
    break
  fi
  VALUE="${VALUE}"
  sleep 5
done
[ -n "$VALUE" ] || fail "the series dora:deployments:increase6h has no data (create the recording rule in a PrometheusRule with the label release: kps)"
awk -v v="$VALUE" 'BEGIN {exit !(v >= 8 && v <= 11)}' \
  || fail "dora:deployments:increase6h is $VALUE, expected a value between 8 and 11 (ten syncs of scout)"

EXPR="$(prom 'rules?type=record' | jq -r '[.data.groups[].rules[] | select(.name == "dora:deployments:increase6h")][0].query // empty' | tr -d ' ')"
[ -n "$EXPR" ] || fail "Prometheus has no loaded rule named dora:deployments:increase6h"
case "$EXPR" in *argocd_app_sync_total*) ;; *) fail "the rule does not read argocd_app_sync_total: '$EXPR'";; esac
case "$EXPR" in *increase\(*|*rate\(*) ;; *) fail "the rule does not use increase() on the counter: '$EXPR'";; esac
case "$EXPR" in *vector\(*) fail "the rule uses vector(); a typed-in number does not measure anything";; esac

echo "PASS: dora:deployments:increase6h is $VALUE and reads the sync counter"

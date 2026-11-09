#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
expr=$(kubectl -n monitoring get prometheusrule dora-scout -o json | jq -r '.spec.groups[].rules[] | select(.record == "dora:deployments:increase6h") | .expr')
[[ "$expr" == *argocd_app_sync_total* && "$expr" == *increase* && "$expr" == *Succeeded* ]] || fail 'count successful sync increases from the source counter'
query() {
 local q
 q=$(jq -rn --arg q "$1" '$q | @uri')
 kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$q" | jq -r '.data.result[0].value[1] // empty'
}
for attempt in $(seq 1 60); do
 actual=$(query 'dora:deployments:increase6h')
 expected=$(query 'round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))')
 if awk -v a="$actual" -v e="$expected" 'BEGIN {exit !(a ~ /^[0-9.]+$/ && e > 0 && a == e)}'; then
  echo "PASS: recorded $actual successful syncs, matching the counter increase"; exit 0
 fi
 sleep 5
done
fail 'the recorded deployment count does not match successful syncs'

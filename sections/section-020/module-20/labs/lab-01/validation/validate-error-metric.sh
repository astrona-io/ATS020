#!/usr/bin/env bash
# Grades the behaviour: the metric made from log lines must carry the labels
# that name the workload, and it must keep rising while probe logs errors.
# Two samples taken 45 seconds apart must differ.
set -u
fail() { echo "FAIL: $*"; exit 1; }

PROM='/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy'
SELECTOR='log_error_lines_total{k8s_namespace_name="outpost",k8s_deployment_name="probe"}'

prom_sum() {
  kubectl get --raw "$PROM/api/v1/query?query=$(jq -rn --arg q "sum($1)" '$q|@uri')" 2>/dev/null |
    jq -r '.data.result[0].value[1] // empty'
}

first=""
for _ in $(seq 1 36); do
  first=$(prom_sum "$SELECTOR")
  [[ -n "$first" ]] && break
  sleep 5
done
[[ -n "$first" ]] || fail "Prometheus has no series $SELECTOR; the labels k8s_namespace_name and k8s_deployment_name are missing or the target is not scraped"

sleep 45
second=$(prom_sum "$SELECTOR")
[[ -n "$second" ]] || fail "the series $SELECTOR disappeared"
awk -v a="$first" -v b="$second" 'BEGIN { exit !(b > a) }' \
  || fail "log_error_lines_total did not rise in 45 seconds (first $first, second $second); probe logs an error every 4 seconds"
echo "PASS: log_error_lines_total for probe in outpost rose from $first to $second"

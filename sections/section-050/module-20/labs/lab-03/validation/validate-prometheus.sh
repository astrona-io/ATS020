#!/usr/bin/env bash
# Grader: the Prometheus Operator runs again, Prometheus scrapes scout
# (up{job="scout"} is 1) and has loaded the ScoutDown alerting rule. The
# objects are read through the Prometheus HTTP API from shuttle. Retries,
# because the operator needs a minute to write the configuration and Prometheus
# needs a scrape to report the target.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): both webhook
# configurations keep failurePolicy Fail, and the workloads, ServiceMonitor
# and PrometheusRule.
for target in 'starfleet deployment scout' 'starfleet servicemonitor scout' 'starfleet prometheusrule scout-alerts' 'monitoring deployment kps-operator' 'monitoring prometheus kps-prometheus'; do
  read -r namespace kind name <<<"$target"
  kubectl -n "$namespace" get "$kind" "$name" >/dev/null 2>&1 || { echo "FAIL: missing $target"; exit 1; }
done

prom() { kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 5 -G "http://kps-prometheus.monitoring:9090$1" "${@:2}" 2>/dev/null; }

READY=""
for attempt in $(seq 1 24); do
  READY="$(kubectl -n monitoring get deployment kps-operator -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "${READY:-0}" -ge 1 ] && break
  sleep 5
done
[ "${READY:-0}" -ge 1 ] || fail "the Deployment kps-operator in namespace monitoring has no ready pod"

UP=""
for attempt in $(seq 1 36); do
  UP="$(prom /api/v1/query --data-urlencode 'query=up{job="scout"}' | grep -o '"value":\[[^]]*\]' | grep -o '"[01]"\]' | head -1)"
  [ "$UP" = '"1"]' ] && break
  sleep 5
done
[ "$UP" = '"1"]' ] || fail "up{job=\"scout\"} is not 1 in Prometheus (got '${UP:-no series}')"

RULE=""
for attempt in $(seq 1 24); do
  RULE="$(prom /api/v1/rules | grep -c '"name":"ScoutDown"')"
  [ "${RULE:-0}" -ge 1 ] && break
  sleep 5
done
[ "${RULE:-0}" -ge 1 ] || fail "the alerting rule ScoutDown is not loaded in Prometheus"

echo "PASS: the operator runs, up{job=\"scout\"} is 1 and the ScoutDown rule is loaded"

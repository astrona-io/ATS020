#!/usr/bin/env bash
# Grader: Prometheus returns the change failure rate that the delivery
# history holds. Two of the nine counted deployments went Degraded, so the
# ratio is about 0.22. It must be above 0.15 and below 0.30. Zero (the faulty
# rule) and one (a rule that counts everything) both fail. Retries, because a
# changed rule reaches Prometheus after about 60 seconds and is then
# evaluated every 15 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

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
fail "dora:change_failure_rate:ratio6h is '${VALUE:-no data}', expected a value between 0.15 and 0.30 (two failed deployments out of nine)"

#!/usr/bin/env bash
# Grader: Prometheus reports the alert ScoutErrorBudgetBurn in the state
# firing. The alert waits for its `for` time after the rule reaches
# Prometheus (about 60 seconds), so this script retries for up to 8 minutes.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

STATE=""
for attempt in $(seq 1 96); do
  STATE="$(kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts" 2>/dev/null \
    | jq -r '[.data.alerts[] | select(.labels.alertname == "ScoutErrorBudgetBurn")][0].state // empty' 2>/dev/null)"
  if [ "$STATE" = "firing" ]; then
    echo "PASS: ScoutErrorBudgetBurn is firing"
    exit 0
  fi
  sleep 5
done
fail "ScoutErrorBudgetBurn is '${STATE:-not active}', expected firing (scout fails 5% of its requests, a burn rate of about 5)"

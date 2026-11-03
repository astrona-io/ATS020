#!/usr/bin/env bash
# Grader: the alert ScoutHighErrorRatio fires for the namespace frontier with
# the label team: frontier. The rule that Prometheus loaded must wait one
# minute (for: 1m), compare with 0.05 and use the recorded series, so lowering
# the wait, raising the threshold or writing a constant expression fails.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1" 2>/dev/null
}

RULE=""
for attempt in $(seq 1 36); do
  RULE="$(api rules | jq -c '[.data.groups[].rules[] | select(.name == "ScoutHighErrorRatio")][0] // empty' 2>/dev/null)"
  [ -n "$RULE" ] && break
  sleep 5
done
[ -n "$RULE" ] || fail "Prometheus has not loaded a rule named ScoutHighErrorRatio"

DURATION="$(echo "$RULE" | jq -r '.duration')"
QUERY="$(echo "$RULE" | jq -r '.query')"
[ "$DURATION" = "60" ] || fail "the alert waits ${DURATION}s, expected 60s (for: 1m)"
echo "$QUERY" | grep -q 'namespace:http_requests_error_ratio:rate1m' || fail "the alert must use the recorded series namespace:http_requests_error_ratio:rate1m (found: $QUERY)"
echo "$QUERY" | grep -Eq '> *0?\.05([^0-9]|$)' || fail "the alert must compare with 0.05 (5%) (found: $QUERY)"

for attempt in $(seq 1 60); do
  FIRING="$(api alerts | jq '[.data.alerts[] | select(.labels.alertname == "ScoutHighErrorRatio" and .labels.namespace == "frontier" and .labels.team == "frontier" and .state == "firing")] | length' 2>/dev/null)"
  if [ "${FIRING:-0}" -ge 1 ]; then
    echo "PASS: ScoutHighErrorRatio fires for frontier with team=frontier"
    exit 0
  fi
  sleep 5
done
fail "ScoutHighErrorRatio is not firing for the namespace frontier with team=frontier"

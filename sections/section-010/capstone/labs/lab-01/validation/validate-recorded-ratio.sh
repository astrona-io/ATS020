#!/usr/bin/env bash
# Grader: the recorded series namespace:http_requests_error_ratio:rate1m exists
# for frontier and is close to the error ratio that Prometheus calculates
# directly from http_requests_total. The shuttle loop makes about one request in
# six fail, so a correct series is near 0.17. A hard-coded value or a rule that
# matches no status fails.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

query() {
  local encoded
  encoded="$(jq -rn --arg q "$1" '$q|@uri')"
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=${encoded}" 2>/dev/null | jq -r '.data.result[0].value[1] // empty' 2>/dev/null
}

RECORDED=""; DIRECT=""
for attempt in $(seq 1 36); do
  RECORDED="$(query 'namespace:http_requests_error_ratio:rate1m{namespace="frontier"}')"
  DIRECT="$(query 'sum(rate(http_requests_total{job="scout",namespace="frontier",status=~"5.."}[2m])) / sum(rate(http_requests_total{job="scout",namespace="frontier"}[2m]))')"
  if [ -n "$RECORDED" ] && [ -n "$DIRECT" ]; then
    if awk -v r="$RECORDED" -v d="$DIRECT" 'BEGIN { diff = r - d; if (diff < 0) diff = -diff; exit !(r > 0.05 && r < 0.4 && diff < 0.06) }'; then
      echo "PASS: the recorded error ratio for frontier is $RECORDED (direct query $DIRECT)"
      exit 0
    fi
  fi
  sleep 5
done
fail "the series namespace:http_requests_error_ratio:rate1m{namespace=\"frontier\"} is '${RECORDED:-missing}' and the direct ratio is '${DIRECT:-missing}'; it must exist and match the real error ratio"

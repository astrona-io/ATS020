#!/usr/bin/env bash
# Grader: scout:error_ratio:rate5m returns exactly one series and its value is
# the real error ratio of the scout requests in starfleet. The grader computes
# the true ratio itself from the raw counter and accepts a difference of 0.03.
# The traffic loop makes about 0.12, so the faulty rule (a few thousandths) and
# a ratio of zero or one both fail. Retries, because a changed rule reaches
# Prometheus after about 60 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

query() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$1" 2>/dev/null
}

REFERENCE='sum(rate(http_requests_total%7Bnamespace%3D%22starfleet%22%2Cstatus%3D~%225..%22%7D%5B5m%5D))%20%2F%20sum(rate(http_requests_total%7Bnamespace%3D%22starfleet%22%7D%5B5m%5D))'

COUNT=0; VALUE=""; TRUE=""
for attempt in $(seq 1 36); do
  RESULT="$(query 'scout:error_ratio:rate5m')"
  COUNT="$(echo "$RESULT" | jq '.data.result | length' 2>/dev/null)"
  VALUE="$(echo "$RESULT" | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  TRUE="$(query "$REFERENCE" | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ "${COUNT:-0}" = "1" ] && [ -n "$VALUE" ] && [ -n "$TRUE" ] \
     && awk -v v="$VALUE" -v t="$TRUE" 'BEGIN {d = v - t; if (d < 0) d = -d; exit !(d < 0.03 && t > 0.05 && t < 0.25)}'; then
    echo "PASS: scout:error_ratio:rate5m is $VALUE (the real ratio is $TRUE)"
    exit 0
  fi
  sleep 5
done
fail "scout:error_ratio:rate5m returns ${COUNT:-0} series with value '${VALUE:-none}', expected one series close to the real error ratio '${TRUE:-no data}'"

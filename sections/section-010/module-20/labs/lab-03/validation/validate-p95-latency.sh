#!/usr/bin/env bash
# Grader: scout:request_duration_seconds:p95_5m returns exactly one series, and
# its value is the real 95th percentile of the scout request duration in
# starfleet. The grader computes the true percentile from the raw buckets and
# accepts a difference of 25 percent. The faulty rule returns one series for
# each bucket series, so it fails on the count. Retries, because a changed rule
# reaches Prometheus after about 60 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

query() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$1" 2>/dev/null
}

REFERENCE='histogram_quantile(0.95%2C%20sum%20by%20(le)%20(rate(http_request_duration_seconds_bucket%7Bnamespace%3D%22starfleet%22%7D%5B5m%5D)))'

COUNT=0; VALUE=""; TRUE=""
for attempt in $(seq 1 36); do
  RESULT="$(query 'scout:request_duration_seconds:p95_5m')"
  COUNT="$(echo "$RESULT" | jq '.data.result | length' 2>/dev/null)"
  VALUE="$(echo "$RESULT" | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  TRUE="$(query "$REFERENCE" | jq -r '.data.result[0].value[1] // empty' 2>/dev/null)"
  if [ "${COUNT:-0}" = "1" ] && [ -n "$VALUE" ] && [ -n "$TRUE" ] \
     && awk -v v="$VALUE" -v t="$TRUE" 'BEGIN {d = v - t; if (d < 0) d = -d; exit !(t > 0.5 && d < 0.25 * t)}'; then
    echo "PASS: scout:request_duration_seconds:p95_5m is $VALUE (the real p95 is $TRUE)"
    exit 0
  fi
  sleep 5
done
fail "scout:request_duration_seconds:p95_5m returns ${COUNT:-0} series with value '${VALUE:-none}', expected one series close to the real p95 '${TRUE:-no data}'"

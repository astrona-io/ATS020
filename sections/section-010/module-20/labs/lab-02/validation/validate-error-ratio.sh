#!/usr/bin/env bash
# Grader: scout:error_ratio:rate5m returns exactly one series and its value is
# the real error ratio of the scout requests in starfleet. The grader computes
# the true ratio itself from the raw counter and accepts a difference of 0.03.
# The traffic loop makes about 0.12, so the faulty rule (a few thousandths) and
# a ratio of zero or one both fail. Retries, because a changed rule reaches
# Prometheus after about 60 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay: the PrometheusRule scout-queries keeps the label
# release: kps and exactly the two recording rules, each expression reads the
# real metric with no vector() or scalar(), and the other rule is unchanged.
# Deleting a rule or typing the value is rejected.
kubectl -n monitoring get prometheusrule scout-queries >/dev/null 2>&1 || fail "the PrometheusRule scout-queries in monitoring is missing"
LABEL="$(kubectl -n monitoring get prometheusrule scout-queries -o jsonpath='{.metadata.labels.release}' 2>/dev/null)"
[ "$LABEL" = "kps" ] || fail "the PrometheusRule scout-queries must have the label release: kps (found '${LABEL:-none}')"

RULES="$(kubectl -n monitoring get prometheusrule scout-queries -o json | jq -r '[.spec.groups[].rules[] | select(.record != null) | .record] | sort | join(",")')"
[ "$RULES" = "scout:error_ratio:rate5m,scout:request_duration_seconds:p95_5m" ] \
  || fail "the PrometheusRule must hold exactly the recording rules scout:error_ratio:rate5m and scout:request_duration_seconds:p95_5m (found '${RULES:-none}')"

expr_of() {
  kubectl -n monitoring get prometheusrule scout-queries -o json \
    | jq -r --arg name "$1" '[.spec.groups[].rules[] | select(.record == $name) | .expr][0]'
}

RATIO_EXPR="$(expr_of scout:error_ratio:rate5m)"
LATENCY_EXPR="$(expr_of scout:request_duration_seconds:p95_5m)"

echo "$RATIO_EXPR" | grep -q 'http_requests_total' || fail "scout:error_ratio:rate5m must read http_requests_total"
echo "$LATENCY_EXPR" | grep -q 'http_request_duration_seconds_bucket' || fail "scout:request_duration_seconds:p95_5m must read http_request_duration_seconds_bucket"
for expr in "$RATIO_EXPR" "$LATENCY_EXPR"; do
  echo "$expr" | grep -Eq 'vector\(|scalar\(' && fail "an expression types a number with vector() or scalar(); it must come from the metrics"
done

[ "$(printf '%s' "$LATENCY_EXPR" | tr -d '[:space:]')" = 'histogram_quantile(0.95,sumby(le)(rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m])))' ] || fail 'keep the unassigned recording rule unchanged'

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

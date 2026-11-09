#!/usr/bin/env bash
# Grader: the PrometheusRule scout-queries still exists in monitoring with the
# label release: kps and exactly the two recording rules with their names.
# Each expression must read the real metric (http_requests_total or the
# http_request_duration_seconds_bucket histogram) and must not type a number
# with vector() or scalar(). Deleting a rule or typing the value is rejected.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

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

[ "$(printf '%s' "$RATIO_EXPR" | tr -d '[:space:]')" = 'sum(rate(http_requests_total{namespace="starfleet",status=~"5.."}[5m]))/sum(rate(http_requests_total{namespace="starfleet"}[5m]))' ] || fail 'keep the unassigned recording rule unchanged'

echo "PASS: the PrometheusRule scout-queries holds both recording rules and they read the real metrics"

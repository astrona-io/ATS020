#!/usr/bin/env bash
# Grader: the fix keeps the design. The Prometheus resource still selects
# release: kps, the Service scout keeps its label and port, the receiver keeps
# its port, the workloads still run, and the three objects scout (ServiceMonitor
# and PrometheusRule) and frontier (AlertmanagerConfig) still exist. The
# AlertmanagerConfig still routes team: frontier, and the recording rule still
# reads http_requests_total. A fix that widens a selector, changes the Service
# or the receiver, deletes an object or hard-codes the numbers is rejected.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

SELECTOR="$(kubectl -n monitoring get prometheus kps-prometheus -o jsonpath='{.spec.serviceMonitorSelector.matchLabels.release}' 2>/dev/null)"
[ "$SELECTOR" = "kps" ] || fail "the Prometheus resource must still select release: kps for ServiceMonitors (found '${SELECTOR:-none}')"
RULE_SELECTOR="$(kubectl -n monitoring get prometheus kps-prometheus -o jsonpath='{.spec.ruleSelector.matchLabels.release}' 2>/dev/null)"
[ "$RULE_SELECTOR" = "kps" ] || fail "the Prometheus resource must still select release: kps for PrometheusRules (found '${RULE_SELECTOR:-none}')"

PORT_NAME="$(kubectl -n frontier get service scout -o jsonpath='{.spec.ports[0].name}' 2>/dev/null)"
[ "$PORT_NAME" = "http" ] || fail "the Service scout must still name its port http (found '${PORT_NAME:-none}')"
SVC_LABEL="$(kubectl -n frontier get service scout -o jsonpath='{.metadata.labels.app}' 2>/dev/null)"
[ "$SVC_LABEL" = "scout" ] || fail "the Service scout must still have the label app: scout (found '${SVC_LABEL:-none}')"

RECEIVER_PORT="$(kubectl -n monitoring get service alert-receiver -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)"
[ "$RECEIVER_PORT" = "8080" ] || fail "the Service alert-receiver must still use port 8080 (found '${RECEIVER_PORT:-none}'); fix the URL in the AlertmanagerConfig, not the receiver"

REPLICAS="$(kubectl -n frontier get deployment scout -o jsonpath='{.spec.replicas}' 2>/dev/null)"
[ "$REPLICAS" = "2" ] || fail "the Deployment scout in frontier must keep 2 replicas (found '${REPLICAS:-none}')"
kubectl -n frontier get deployment shuttle >/dev/null 2>&1 || fail "the Deployment shuttle in frontier is missing"
kubectl -n frontier get configmap shuttle-traffic -o jsonpath='{.data.traffic\.sh}' 2>/dev/null | grep -q '/status/500' \
  || fail "the traffic loop of shuttle must still send failing requests"

kubectl -n frontier get servicemonitor scout >/dev/null 2>&1 || fail "the ServiceMonitor scout in frontier is missing"
LABEL="$(kubectl -n frontier get servicemonitor scout -o jsonpath='{.metadata.labels.release}' 2>/dev/null)"
[ "$LABEL" = "kps" ] || fail "the ServiceMonitor scout must have the label release: kps (found '${LABEL:-none}')"

kubectl -n frontier get prometheusrule scout >/dev/null 2>&1 || fail "the PrometheusRule scout in frontier is missing"
RULES="$(kubectl -n frontier get prometheusrule scout -o json 2>/dev/null)"
echo "$RULES" | jq -e '[.spec.groups[].rules[] | select(.record == "namespace:http_requests_error_ratio:rate1m")] | length == 1' >/dev/null \
  || fail "the PrometheusRule scout must keep the recording rule namespace:http_requests_error_ratio:rate1m"
echo "$RULES" | jq -e '[.spec.groups[].rules[] | select(.record == "namespace:http_requests_error_ratio:rate1m") | .expr | select(test("http_requests_total") and test("rate\\("))] | length == 1' >/dev/null \
  || fail "the recording rule must calculate the ratio from rate(http_requests_total...), not use a fixed value"
echo "$RULES" | jq -e '[.spec.groups[].rules[] | select(.alert == "ScoutHighErrorRatio") | select(.labels.team == "frontier")] | length == 1' >/dev/null \
  || fail "the PrometheusRule scout must keep the alert ScoutHighErrorRatio with the label team: frontier"

kubectl -n frontier get alertmanagerconfig frontier >/dev/null 2>&1 || fail "the AlertmanagerConfig frontier in frontier is missing"
kubectl -n frontier get alertmanagerconfig frontier -o json | jq -e '[.spec.route.matchers[]? | select(.name == "team" and .value == "frontier")] | length == 1' >/dev/null \
  || fail "the AlertmanagerConfig frontier must route alerts with team = frontier"

echo "PASS: the selectors, the Service, the receiver, the workloads and the three monitoring objects are fixed in place"

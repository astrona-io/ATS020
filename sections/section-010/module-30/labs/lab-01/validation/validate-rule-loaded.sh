#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
prometheus_api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1"
}
alertmanager_api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/$1"
}

kubectl -n monitoring get prometheus kps-prometheus -o json | jq -e '
 .spec.ruleSelector.matchLabels.release == "kps" and .spec.ruleNamespaceSelector == {}' >/dev/null || fail 'Keep the Prometheus selectors unchanged'
kubectl -n starfleet get prometheusrule scout-errors -o json | jq -e '.metadata.labels.release == "kps" and ([.spec.groups[].rules[]] | length == 1 and .[0].alert == "ScoutErrorRate")' >/dev/null || fail 'Label scout-errors release=kps'
prometheus_api rules | jq -e --arg expected 'sum by (namespace) (rate(http_requests_total{job="scout",namespace="starfleet",status="500"}[1m])) > 0.1' '
 [.data.groups[].rules[] | select(.name == "ScoutErrorRate" and .type == "alerting")]
 | length == 1 and (.[0] | .health == "ok" and .duration == 60
 and .labels.team == "scout" and .labels.severity == "warning"
 and ((.query | gsub("\\s"; "")) == ($expected | gsub("\\s"; ""))))' >/dev/null || fail 'Load the specified ScoutErrorRate rule, threshold, for and labels'
echo 'PASS: rule-loaded'

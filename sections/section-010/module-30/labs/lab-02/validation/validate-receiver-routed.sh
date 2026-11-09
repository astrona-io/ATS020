#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
prometheus_api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1"
}
alertmanager_api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/$1"
}

alertmanager_api alerts | jq -e 'any(.[];
 .labels.alertname == "ScoutErrorRate" and .labels.namespace == "starfleet"
 and .labels.team == "scout" and .status.state == "active"
 and any(.receivers[]; .name == "starfleet/scout-routing/scout-webhook"))' >/dev/null || fail 'Route the active alert to starfleet/scout-routing/scout-webhook'
kubectl -n monitoring logs deploy/alert-receiver | grep -q 'starfleet/scout-routing/scout-webhook firing ScoutErrorRate namespace=starfleet severity=warning' || fail 'The webhook has not received ScoutErrorRate'
echo 'PASS: receiver-routed'

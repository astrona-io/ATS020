#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
prometheus_api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1"
}
alertmanager_api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/$1"
}

prometheus_api alerts | jq -e 'any(.data.alerts[];
 .labels.alertname == "ScoutErrorRate" and .labels.namespace == "starfleet"
 and .labels.team == "scout" and .labels.severity == "warning" and .state == "firing")' >/dev/null || fail 'Wait for ScoutErrorRate to fire for starfleet'
echo 'PASS: alert-firing'

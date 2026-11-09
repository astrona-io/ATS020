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
 .labels.alertname == "ProbeMaintenance" and .labels.namespace == "starfleet" and .state == "firing")' >/dev/null || fail 'Keep ProbeMaintenance firing in Prometheus'
SILENCES="$(alertmanager_api silences)"
SILENCE_IDS="$(echo "$SILENCES" | jq -c '[.[] | select(.status.state == "active"
 and .createdBy == "platform" and .comment == "probe maintenance window")
 | select((.matchers | length) == 2)
 | select(any(.matchers[]; .name == "alertname" and .value == "ProbeMaintenance" and .isRegex == false and .isEqual != false))
 | select(any(.matchers[]; .name == "namespace" and .value == "starfleet" and .isRegex == false and .isEqual != false))
 | select(((.endsAt | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)
 - (.startsAt | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) == 1800) | .id]')"
echo "$SILENCE_IDS" | jq -e 'length > 0' >/dev/null || fail 'Create an active scoped 30-minute silence with the requested author and comment'
alertmanager_api alerts | jq -e --argjson ids "$SILENCE_IDS" 'any(.[];
 .labels.alertname == "ProbeMaintenance" and .labels.namespace == "starfleet"
 and .status.state == "suppressed"
 and any(.status.silencedBy[]; . as $id | $ids | index($id) != null))' >/dev/null || fail 'The active silence must suppress ProbeMaintenance'
alertmanager_api alerts | jq -e 'any(.[];
 .labels.alertname == "ScoutErrorRate" and .labels.namespace == "starfleet"
 and .status.state == "active" and (.status.silencedBy | length) == 0)' >/dev/null || fail 'Keep ScoutErrorRate active and unsilenced'
echo 'PASS: maintenance-silenced'

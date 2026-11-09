#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
config=$(kubectl -n starfleet get alertmanagerconfig scout-decisions -o json)
jq -e --argjson expected '{"route":{"receiver":"scout-default","matchers":[{"name":"team","value":"scout","matchType":"="}],"groupWait":"10s","groupInterval":"1m","repeatInterval":"5m","routes":[{"receiver":"scout-warning","matchers":[{"name":"severity","value":"warning","matchType":"="}]},{"receiver":"scout-archive","matchers":[{"name":"alertname","value":"Scout.*","matchType":"=~"}]}]},"receivers":[{"name":"scout-default","webhookConfigs":[{"url":"http://alert-receiver.monitoring:8080/"}]},{"name":"scout-warning","webhookConfigs":[{"url":"http://alert-receiver.monitoring:8080/"}]},{"name":"scout-archive","webhookConfigs":[{"url":"http://alert-receiver.monitoring:8080/"}]}]}' '.spec | del(.route.groupBy, .route.routes[0].continue) | . == $expected' <<<"$config" >/dev/null || fail 'keep unrelated routing, matchers, receivers and timing unchanged'
check() {
body=$(kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts)
jq -e '[.[] | select(.labels.alertname == "ScoutRouteCheck")] | length == 2 and all(.[];
 [.receivers[].name] | sort == ["starfleet/scout-decisions/scout-archive","starfleet/scout-decisions/scout-warning"])
' <<<"$body" >/dev/null || return 1
groups=$(kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts/groups)
jq -e '[.[] | select(.receiver.name == "starfleet/scout-decisions/scout-warning" or .receiver.name == "starfleet/scout-decisions/scout-archive")] |
 length == 2 and all(.[]; (.labels | keys | sort) == ["alertname","namespace"] and ([.alerts[] | select(.labels.alertname == "ScoutRouteCheck")] | length) == 2)' <<<"$groups" >/dev/null
}
for attempt in $(seq 1 60); do
  if check; then echo 'PASS: live alert behaviour matches the task'; exit 0; fi
  sleep 5
done
fail 'the live alert state does not match the requested routing or suppression'

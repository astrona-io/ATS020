#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
config=$(kubectl -n starfleet get alertmanagerconfig scout-inhibition -o json)
jq -e --argjson expected '{"route":{"receiver":"scout-webhook","matchers":[{"name":"team","value":"scout-inhibit","matchType":"="}],"groupBy":["namespace","alertname"],"groupWait":"10s","groupInterval":"1m","repeatInterval":"5m"},"receivers":[{"name":"scout-webhook","webhookConfigs":[{"url":"http://alert-receiver.monitoring:8080/"}]}],"inhibitRules":[{"sourceMatch":[{"name":"team","value":"scout-inhibit","matchType":"="},{"name":"severity","matchType":"="},{"name":"alertname","value":"ScoutUnavailable","matchType":"="}],"targetMatch":[{"name":"team","value":"scout-inhibit","matchType":"="},{"name":"severity","value":"warning","matchType":"="},{"name":"alertname","value":"ScoutLatency","matchType":"="}],"equal":["namespace","team"]}]}' '.spec | del(.inhibitRules[0].sourceMatch[1].value) | . == $expected' <<<"$config" >/dev/null || fail 'keep unrelated routing, matchers, receivers and timing unchanged'
check() {
rules=$(kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts)
jq -e '[.data.alerts[] | select(.labels.team == "scout-inhibit" and .labels.namespace == "starfleet" and .state == "firing") | .labels.alertname] | sort == ["ScoutLatency","ScoutUnavailable"]' <<<"$rules" >/dev/null || return 1
body=$(kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts)
jq -e '
 [.[] | select(.labels.team == "scout-inhibit" and .labels.namespace == "starfleet")] as $alerts |
 [$alerts[] | select(.labels.alertname == "ScoutUnavailable" and .labels.severity == "critical" and .status.state == "active")] as $source |
 [$alerts[] | select(.labels.alertname == "ScoutLatency" and .labels.severity == "warning")] as $target |
 ($source | length) == 1 and ($target | length) == 1 and
 ($target[0].status.state == "suppressed") and
 ($target[0].status.silencedBy | length) == 0 and
 ($target[0].status.inhibitedBy | index($source[0].fingerprint)) != null
' <<<"$body" >/dev/null
}
for attempt in $(seq 1 60); do
  if check; then echo 'PASS: live alert behaviour matches the task'; exit 0; fi
  sleep 5
done
fail 'the live alert state does not match the requested routing or suppression'

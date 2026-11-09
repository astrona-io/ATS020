#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
kubectl -n outpost get podmonitor scout -o json | jq -e '.metadata.labels.release == "kps" and .spec.selector.matchLabels.app == "scout" and .spec.podMetricsEndpoints[0].port == "http"' >/dev/null || fail 'create the selected PodMonitor with the named container port'
if kubectl -n outpost get service scout >/dev/null 2>&1; then fail 'do not add a Service'; fi
for attempt in $(seq 1 48); do
  expected=$(kubectl -n outpost get pods -l app=scout -o json | jq -c '[.items[] | select(.metadata.deletionTimestamp == null and any(.status.conditions[]?; .type == "Ready" and .status == "True")) | .status.podIP + ":9898"] | sort')
  targets=$(kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/targets?state=active')
  actual=$(jq -c '[.data.activeTargets[] | select(.scrapePool == "podMonitor/outpost/scout/0" and .health == "up") | .labels.instance] | sort' <<<"$targets")
  if [ "$expected" != '[]' ] && [ "$actual" = "$expected" ]; then echo 'PASS: every ready Pod is a healthy PodMonitor target'; exit 0; fi
  sleep 5
done
fail 'PodMonitor targets do not match all ready Pods'

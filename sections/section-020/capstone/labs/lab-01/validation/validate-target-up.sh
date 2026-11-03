#!/usr/bin/env bash
# Grades the scrape target: Prometheus must list the Collector's metric
# endpoint (port 8889) and its last scrape must have worked. A new
# target appears about a minute after the ServiceMonitor is fixed, so retry.
set -u
fail() { echo "FAIL: $*"; exit 1; }

PROM='/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy'
health=""
for _ in $(seq 1 36); do
  health=$(kubectl get --raw "$PROM/api/v1/targets" 2>/dev/null |
    jq -r '[.data.activeTargets[] | select(.scrapeUrl | test(":8889/")) | .health] | join(",")')
  [[ "$health" == "up" ]] && break
  sleep 5
done

[[ -n "$health" ]] || fail "Prometheus has no target for the Collector metric port 8889; check that the ServiceMonitor carries the label the Prometheus resource selects"
[[ "$health" == "up" ]] || fail "the Collector target health is '$health', expected exactly one target that is up"
echo "PASS: Prometheus scrapes the Collector and the target is up"

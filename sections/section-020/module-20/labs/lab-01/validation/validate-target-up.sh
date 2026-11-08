#!/usr/bin/env bash
# Grades the scrape target: Prometheus must list the Collector's metric
# endpoint (job logs-collector) and its last scrape must have worked. A new
# target appears about a minute after the ServiceMonitor is fixed, so retry.
set -u
fail() { echo "FAIL: $*"; exit 1; }

PROM='/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy'
health=""
for _ in $(seq 1 36); do
  health=$(kubectl get --raw "$PROM/api/v1/targets" 2>/dev/null |
    jq -r '[.data.activeTargets[] | select(.labels.job=="logs-collector") | .health] | join(",")')
  [[ "$health" == "up" ]] && break
  sleep 5
done

[[ -n "$health" ]] || fail "Prometheus has no target for the job logs-collector; check that the ServiceMonitor carries the label the Prometheus resource selects"
[[ "$health" == "up" ]] || fail "the logs-collector target health is '$health', expected exactly one target that is up"
echo "PASS: Prometheus scrapes the Collector and the target is up"

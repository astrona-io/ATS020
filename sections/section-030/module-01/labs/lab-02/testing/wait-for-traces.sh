#!/usr/bin/env bash
# Helper for `astrona test`: wait until Jaeger knows all three services, so the
# reference solution can search by tag. Each workload sends a trace every few
# seconds, and Jaeger batches spans before it stores them.
set -uo pipefail
for attempt in $(seq 1 36); do
  services="$(kubectl get --raw '/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/services' 2>/dev/null || true)"
  if jq -e '[.services[]] | contains(["scout", "probe", "shuttle"])' <<<"$services" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 5
done
echo 'Jaeger did not list scout, probe and shuttle in time' >&2
exit 1

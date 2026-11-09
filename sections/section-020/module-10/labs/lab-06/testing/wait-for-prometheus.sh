#!/usr/bin/env bash
# Helper for `astrona test`: waits until Prometheus answers queries through the
# API server proxy and holds scout request metrics, so the validation scripts
# do not start too early.
set -u
PROM='/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy'
for _ in $(seq 1 90); do
  count=$(kubectl get --raw "$PROM/api/v1/query?query=count(http_requests_total)" 2>/dev/null |
    jq -r '.data.result[0].value[1] // 0')
  if [[ "$count" != "0" ]]; then
    echo "Prometheus is ready and holds scout metrics"
    exit 0
  fi
  sleep 5
done
echo "Prometheus did not return scout metrics" >&2
exit 1

#!/usr/bin/env bash
# Helper for `astrona test`: waits until Prometheus holds the scout request
# metrics and the metric made from the probe logs, so the validation scripts
# do not start too early.
set -u
PROM='/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy'
query_count() {
  kubectl get --raw "$PROM/api/v1/query?query=$(jq -rn --arg q "count($1)" '$q|@uri')" 2>/dev/null |
    jq -r '.data.result[0].value[1] // 0'
}
for _ in $(seq 1 90); do
  if [[ "$(query_count http_requests_total)" != "0" && "$(query_count log_error_lines_total)" != "0" ]]; then
    echo "Prometheus holds scout metrics and the log error metric"
    exit 0
  fi
  sleep 5
done
echo "Prometheus did not return both metrics" >&2
exit 1

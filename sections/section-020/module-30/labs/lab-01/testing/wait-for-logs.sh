#!/usr/bin/env bash
set -euo pipefail
LOKI_API=/api/v1/namespaces/logging/services/loki:3100/proxy/loki/api/v1
query=$(jq -rn --arg q 'count(rate({namespace="outpost"} |= "ERROR" [5m]))' '$q | @uri')
for attempt in $(seq 1 60); do
  if kubectl get --raw "$LOKI_API/query?query=$query" 2>/dev/null |
    jq -e '.data.resultType == "vector" and any(.data.result[]; (.value[1] | tonumber) > 0)' >/dev/null; then
    exit 0
  fi
  sleep 5
done
echo 'Loki did not receive outpost error logs within five minutes' >&2
exit 1

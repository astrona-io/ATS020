#!/usr/bin/env bash
# Helper for `astrona test`: waits until both fixed recording rules return one
# series. A changed rule reaches Prometheus after about 60 seconds, and the
# [5m] window needs a few minutes of traffic, so the validation scripts would
# otherwise start too early.
set -uo pipefail

count() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=count($1)" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // 0' 2>/dev/null
}

for attempt in $(seq 1 90); do
  if [ "$(count scout:error_ratio:rate5m)" = "1" ] && [ "$(count scout:request_duration_seconds:p95_5m)" = "1" ]; then
    echo "[testing] Both recording rules return one series."
    exit 0
  fi
  sleep 5
done
echo "[testing] The recording rules did not settle in time (continuing)." >&2
exit 0

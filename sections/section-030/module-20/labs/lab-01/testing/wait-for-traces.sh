#!/usr/bin/env bash
# Helper for `astrona test`: waits until Jaeger holds a recent trace that has
# spans from relay, so the validation scripts see a settled pipeline. The
# Node.js agent and the Collector both batch spans before they export them.
set -uo pipefail

for attempt in $(seq 1 60); do
  START="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=2)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  BODY="$(kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces?query.service_name=relay&query.start_time_min=${START}&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=5" 2>/dev/null || true)"
  if printf '%s' "$BODY" | grep -q '"relay"'; then
    echo "[testing] Jaeger holds recent spans from relay."
    exit 0
  fi
  sleep 5
done
echo "[testing] No recent relay spans in time (continuing)." >&2
exit 0

#!/usr/bin/env bash
# Grader: a trace from scout, with a recent start time, is in Jaeger. Reads
# the Jaeger v3 API on port 16686 through the API server proxy. Retries,
# because scout and the Collector both batch spans before they export them.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

for attempt in $(seq 1 36); do
  START="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=3)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  END="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)+d.timedelta(minutes=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  BODY="$(kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces?query.service_name=scout&query.start_time_min=${START}&query.start_time_max=${END}&query.search_depth=20" 2>/dev/null || true)"
  COUNT="$(printf '%s' "$BODY" | python3 -c '
import json, sys
n = 0
for line in sys.stdin.read().splitlines():
    try:
        doc = json.loads(line)
    except ValueError:
        continue
    for rs in doc.get("result", {}).get("resourceSpans", []):
        names = [a["value"].get("stringValue") for a in rs.get("resource", {}).get("attributes", []) if a.get("key") == "service.name"]
        if "scout" in names:
            for ss in rs.get("scopeSpans", []):
                n += len(ss.get("spans", []))
print(n)' 2>/dev/null)"
  if [ "${COUNT:-0}" -gt 0 ]; then
    echo "PASS: Jaeger holds ${COUNT} recent spans from service scout"
    exit 0
  fi
  sleep 5
done
fail "Jaeger has no span from service scout in the last 3 minutes"

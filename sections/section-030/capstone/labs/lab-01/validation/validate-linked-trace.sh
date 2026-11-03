#!/usr/bin/env bash
# Grader: Jaeger holds a recent trace with spans from BOTH relay and scout,
# and a span of scout has a span of relay as its parent. That proves context
# propagation (the traceparent header), not just two services that both send
# spans. Reads the Jaeger v3 API through the API server proxy. Retries,
# because the agent, scout and the Collector all batch spans.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

for attempt in $(seq 1 48); do
  START="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=3)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  BODY="$(kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces?query.service_name=relay&query.start_time_min=${START}&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=30" 2>/dev/null || true)"
  RESULT="$(printf '%s' "$BODY" | python3 -c '
import json, sys
spans = []
for line in sys.stdin.read().splitlines():
    try:
        doc = json.loads(line)
    except ValueError:
        continue
    for rs in doc.get("result", {}).get("resourceSpans", []):
        names = [a["value"].get("stringValue") for a in rs.get("resource", {}).get("attributes", []) if a.get("key") == "service.name"]
        svc = names[0] if names else ""
        for ss in rs.get("scopeSpans", []):
            for s in ss.get("spans", []):
                spans.append((svc, s["traceId"], s["spanId"], s.get("parentSpanId") or ""))
relay_ids = {(t, sid) for svc, t, sid, p in spans if svc == "relay"}
linked = {t for svc, t, sid, p in spans if svc == "scout" and (t, p) in relay_ids}
print(len(linked), next(iter(linked), ""))' 2>/dev/null)"
  COUNT="${RESULT%% *}"
  if [ "${COUNT:-0}" -gt 0 ] 2>/dev/null; then
    echo "PASS: ${COUNT} recent trace(s) have a scout span whose parent is a relay span (trace ${RESULT#* })"
    exit 0
  fi
  sleep 5
done
fail "no recent trace links a scout span to a relay span; relay and scout spans are in separate traces or relay sends none"

#!/usr/bin/env bash
# Applies the reference solution. Run by `astrona test` only.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE=""
for candidate in "$SCRIPT_DIR/solution.yaml" "./solution/solution.yaml" "./solution.yaml"; do
  [ -f "$candidate" ] && { FILE="$candidate"; break; }
done
[ -n "$FILE" ] || { echo "[solution] ERROR: solution.yaml not found" >&2; exit 1; }
kubectl apply -f "$FILE"
kubectl -n observability rollout status deployment/otel-collector --timeout=180s

kubectl -n starfleet set env deployment/scout OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability:4317
kubectl -n starfleet rollout status deployment/scout --timeout=180s

kubectl -n starfleet patch deployment relay --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"true"}}}}}'
kubectl -n starfleet rollout status deployment/relay --timeout=180s

# The reader names the slow call after reading Jaeger. The reference run does
# the same lookup with the Jaeger API at solve time, so it never guesses a span
# name: it takes the scout span that contains "delay", lasts about one second
# and has no child span (the step that holds the time).
OPERATION=""
for attempt in $(seq 1 36); do
  START="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  BODY="$(kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces?query.service_name=relay&query.start_time_min=${START}&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=40&query.duration_min=500ms" 2>/dev/null || true)"
  OPERATION="$(printf '%s' "$BODY" | python3 -c '
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
                d = int(s["endTimeUnixNano"]) - int(s["startTimeUnixNano"])
                spans.append((svc, s["name"], s["spanId"], s.get("parentSpanId") or "", d))
parents = {p for _, _, _, p, _ in spans if p}
slow = [s for s in spans if s[0] == "scout" and "delay" in s[1] and s[4] > 900_000_000]
leaves = [s for s in slow if s[2] not in parents]
print((leaves or slow or [("", "")])[0][1])' 2>/dev/null)"
  [ -n "$OPERATION" ] && break
  sleep 5
done
[ -n "$OPERATION" ] || { echo "[solution] ERROR: Jaeger holds no slow scout span with 'delay' in its name" >&2; exit 1; }
echo "[solution] slowest scout span found in Jaeger: $OPERATION"
kubectl -n starfleet create configmap slow-call --from-literal=service=scout --from-literal=operation="$OPERATION" --dry-run=client -o yaml | kubectl apply -f -
echo "[solution] tracing set up."

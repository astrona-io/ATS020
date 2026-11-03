#!/usr/bin/env bash
# Grader: the learner read Jaeger and recorded the slow call. The ConfigMap
# `slow-call` in `starfleet` must name the service that holds the time
# (`scout`) and an operation that contains `delay`. The answer is checked
# against Jaeger: the operation must be the exact name of a span of `scout`
# that contains `delay` and lasts about one second in a recent relay trace.
# That accepts both the server span (the whole request) and the inner step.
set -uo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }

SERVICE="$(kubectl -n starfleet get configmap slow-call -o jsonpath='{.data.service}' 2>/dev/null)" \
  || fail "ConfigMap slow-call is missing in namespace starfleet; create it with the keys service and operation"
OPERATION="$(kubectl -n starfleet get configmap slow-call -o jsonpath='{.data.operation}' 2>/dev/null)"
[ "$SERVICE" = "scout" ] || fail "slow-call says the slow service is '$SERVICE'; open the slowest trace in Jaeger and name the service of its deepest long span"
case "$OPERATION" in *delay*) ;; *) fail "slow-call says the slow operation is '$OPERATION'; it must be the span name that contains the delay";; esac

for attempt in $(seq 1 24); do
  START="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  BODY="$(kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces?query.service_name=relay&query.start_time_min=${START}&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=40" 2>/dev/null || true)"
  FOUND="$(printf '%s' "$BODY" | python3 -c '
import json, sys
names = set()
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
                if s["name"] == "GET /readyz":
                    continue
                d = int(s["endTimeUnixNano"]) - int(s["startTimeUnixNano"])
                if svc == "scout" and "delay" in s["name"] and d > 900_000_000:
                    names.add(s["name"])
for name in sorted(names):
    print(name)' 2>/dev/null)"
  if [ -n "$FOUND" ]; then
    if printf '%s\n' "$FOUND" | grep -qxF -- "$OPERATION"; then
      echo "PASS: slow-call names scout and '$OPERATION'; Jaeger holds a scout span with that name of about one second"
      exit 0
    fi
    fail "slow-call says the slow operation is '$OPERATION'; Jaeger shows these slow scout spans: $(printf '%s' "$FOUND" | tr '\n' ';'). Copy one span name exactly"
  fi
  sleep 5
done
fail "Jaeger holds no recent scout span of about one second named after the delay; check that relay and scout are traced"

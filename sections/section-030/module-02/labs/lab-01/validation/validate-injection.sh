#!/usr/bin/env bash
# Grader: the running relay pod was instrumented by the Operator. The pod must
# carry the inject annotation (so the annotation is on the pod template), the
# init container the Operator adds, a propagator list with tracecontext, and
# an exporter endpoint that points at the Collector (not straight at Jaeger).
# Retries, because the Operator replaces the pod after a change.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

POD_JSON=""
for attempt in $(seq 1 24); do
  POD_JSON="$(kubectl -n starfleet get pods -l app=relay -o json 2>/dev/null | python3 -c '
import json, sys
items = [p for p in json.load(sys.stdin)["items"]
         if not p["metadata"].get("deletionTimestamp") and p["status"].get("phase") == "Running"]
items.sort(key=lambda p: p["metadata"]["creationTimestamp"])
print(json.dumps(items[-1]) if items else "")' 2>/dev/null)"
  [ -n "$POD_JSON" ] && break
  sleep 5
done
[ -n "$POD_JSON" ] || fail "no running relay pod in namespace starfleet"

printf '%s' "$POD_JSON" | python3 -c '
import json, sys
pod = json.load(sys.stdin)
def fail(msg):
    print("FAIL: " + msg, file=sys.stderr); sys.exit(1)
ann = pod["metadata"].get("annotations", {})
if ann.get("instrumentation.opentelemetry.io/inject-nodejs") in (None, "", "false"):
    fail("the running relay pod has no instrumentation.opentelemetry.io/inject-nodejs annotation (the annotation must be on the pod template, and the pod must be created after it)")
inits = [c["name"] for c in pod["spec"].get("initContainers", [])]
if "opentelemetry-auto-instrumentation-nodejs" not in inits:
    fail("the relay pod has no init container opentelemetry-auto-instrumentation-nodejs (init containers: %s). The Operator did not inject the agent: check that an Instrumentation exists in the namespace starfleet and that the pod was created after it" % inits)
env = {e["name"]: e.get("value", "") for e in pod["spec"]["containers"][0].get("env", [])}
if "tracecontext" not in env.get("OTEL_PROPAGATORS", "").split(","):
    fail("OTEL_PROPAGATORS is \"%s\"; it must include tracecontext so relay sends the traceparent header" % env.get("OTEL_PROPAGATORS", ""))
endpoint = env.get("OTEL_EXPORTER_OTLP_ENDPOINT", "")
if "otel-collector.observability" not in endpoint:
    fail("relay exports to \"%s\"; it must export to the Collector at otel-collector.observability" % endpoint)
print("PASS: relay pod %s is instrumented, propagators=%s, endpoint=%s" % (pod["metadata"]["name"], env["OTEL_PROPAGATORS"], endpoint))
'

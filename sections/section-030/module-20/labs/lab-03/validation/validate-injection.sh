#!/usr/bin/env bash
# Grader: the running relay pod was instrumented by the Operator. The pod must
# carry the inject annotation (so the annotation is on the pod template), the
# init container the Operator adds, a propagator list with tracecontext, and
# an exporter endpoint that points at the Collector (not straight at Jaeger).
# Retries while the Deployment creates a replacement pod.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first): relay keeps its image, command and
# script with no tracing code added by hand, scout is unchanged and not
# injected, and the Collector otel still exports traces to a real backend.
IMAGE="$(kubectl -n starfleet get deployment relay -o jsonpath='{.spec.template.spec.containers[?(@.name=="relay")].image}' 2>/dev/null)" \
  || fail "Deployment relay is missing in namespace starfleet (do not delete it)"
[ "$IMAGE" = "node:22-alpine" ] || fail "relay image is '$IMAGE', expected node:22-alpine"
COMMAND="$(kubectl -n starfleet get deployment relay -o jsonpath='{.spec.template.spec.containers[?(@.name=="relay")].command[*]}' 2>/dev/null)"
[ "$COMMAND" = "node /app/server.js" ] || fail "relay command is '$COMMAND', expected 'node /app/server.js' (no code changes: the Operator adds the agent)"

SCRIPT="$(kubectl -n starfleet get configmap relay-app -o jsonpath='{.data.server\.js}' 2>/dev/null)"
[ -n "$SCRIPT" ] || fail "ConfigMap relay-app has no server.js"
case "$SCRIPT" in *callScout*) ;; *) fail "server.js of relay was replaced";; esac
case "$SCRIPT" in *traceparent*|*opentelemetry*) fail "server.js of relay contains tracing code; this lab uses auto-instrumentation, not code changes";; esac

SCOUT_ENDPOINT="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.spec.containers[?(@.name=="scout")].env[?(@.name=="OTEL_EXPORTER_OTLP_ENDPOINT")].value}' 2>/dev/null)"
[ "$SCOUT_ENDPOINT" = "http://otel-collector.observability:4317" ] || fail "scout sends to '$SCOUT_ENDPOINT'; it must keep sending to http://otel-collector.observability:4317"
SCOUT_ANN="$(kubectl -n starfleet get deployment scout -o jsonpath='{.spec.template.metadata.annotations}' 2>/dev/null)"
case "$SCOUT_ANN" in *instrumentation.opentelemetry.io*) fail "scout has an instrumentation annotation; scout already traces itself and must not be injected";; esac

MODE="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.mode}' 2>/dev/null)" \
  || fail "OpenTelemetryCollector otel is missing in namespace observability"
[ "$MODE" = "deployment" ] || fail "Collector mode is '$MODE', expected deployment"
EXPORTERS="$(kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.config.service.pipelines.traces.exporters[*]}' 2>/dev/null)"
REAL=""
for name in $EXPORTERS; do
  case "$name" in debug*|logging*|nop*) ;; *) REAL="$REAL $name";; esac
done
[ -n "$REAL" ] || fail "the Collector traces pipeline exports only to '$EXPORTERS'; it must export to Jaeger"

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
if "baggage" not in env.get("OTEL_PROPAGATORS", "").split(","):
    fail("OTEL_PROPAGATORS must retain baggage alongside tracecontext")
if env.get("OTEL_TRACES_SAMPLER") != "parentbased_traceidratio" or env.get("OTEL_TRACES_SAMPLER_ARG") != "1":
    fail("the injected sampler must be parentbased_traceidratio with argument 1")
endpoint = env.get("OTEL_EXPORTER_OTLP_ENDPOINT", "")
if "otel-collector.observability" not in endpoint:
    fail("relay exports to \"%s\"; it must export to the Collector at otel-collector.observability" % endpoint)
print("PASS: relay pod %s is instrumented, propagators=%s, endpoint=%s" % (pod["metadata"]["name"], env["OTEL_PROPAGATORS"], endpoint))
'

#!/usr/bin/env bash
# Smoke test for ats-020-playground-030-02, run by scripts/ci/test-playground.sh
# against a fresh playground (KUBECONFIG points at it). It runs the commands
# the module pages teach, with the YAML taken from the pages, and checks the
# results the pages show:
#   - at the start only scout sends spans, and relay has no init container;
#   - the Instrumentation plus the pod template annotation inject the Node.js
#     agent, and one trace holds spans of relay and scout with scout's root
#     span a child of relay's client span;
#   - a /slow trace has delayHandler as its slowest step (about 1000 ms);
#   - with propagators "baggage" only, the relay trace has no scout span;
#   - an annotation on the Deployment gives no init container, a missing
#     Instrumentation gives the "failed to select" log line, and recreating
#     it plus a restart instruments relay again.
# It changes only the playground cluster. Exit code 0 means every check passed.
set -uo pipefail

module=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
port=16686
failed=0

check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; failed=1; return 1; fi; }
wait_secs() { local start; start=$(date +%s); until [ $(( $(date +%s) - start )) -ge "$1" ]; do sleep 2; done; }
cleanup() { [ -n "${forward_pid:-}" ] && kill "$forward_pid" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

# Writes the first YAML block after "Save this as `<file>`" on a page to $work/<file>.
from_page() {
  awk -v marker="Save this as \`$2\`" 'index($0, marker){f=1;next} f&&/^```yaml/{g=1;next} g&&/^```/{exit} g' \
    "$module/$1" >"$work/$2"
  check "$2 found on the page" "[ -s $work/$2 ]"
}

# Waits for a rollout, then until only the new relay pod is listed.
relay_rolled_out() {
  kubectl -n starfleet rollout status deployment/relay --timeout=180s >/dev/null || return 1
  for _ in $(seq 1 45); do
    [ "$(kubectl -n starfleet get pods -l app=relay --no-headers 2>/dev/null | wc -l | tr -d ' ')" = 1 ] && return 0
    sleep 2
  done
  return 1
}
relay_init() { kubectl -n starfleet get pod -l app=relay -o jsonpath='{.items[0].spec.initContainers[*].name}'; }
relay_env() { kubectl -n starfleet get pod -l app=relay -o jsonpath="{.items[0].spec.containers[0].env[?(@.name==\"$1\")].value}"; }

check "operator rolled out" "kubectl -n opentelemetry-operator-system rollout status deployment/opentelemetry-operator-controller-manager --timeout=120s >/dev/null"
check "webhook certificate ready" "[ \"\$(kubectl -n opentelemetry-operator-system get certificate opentelemetry-operator-serving-cert -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}')\" = True ]"

# Starts the port-forward to Jaeger, or starts it again when it has stopped.
forward() {
  if [ -n "${forward_pid:-}" ] && kill -0 "$forward_pid" 2>/dev/null; then return 0; fi
  [ -n "${forward_pid:-}" ] && echo "port-forward to Jaeger had stopped; starting it again"
  kubectl -n observability port-forward svc/jaeger "$port:16686" >"$work/port-forward.log" 2>&1 &
  forward_pid=$!
  sleep 2
}
forward
api=http://127.0.0.1:$port/api/v3

# Printed when a trace check fails: the last Jaeger answer and the state of
# the pods that send and receive the spans.
trace_debug() {
  echo "--- last Jaeger query: $(cat "$work/curl.err" 2>/dev/null)"
  echo "--- port-forward: $(kill -0 "$forward_pid" 2>/dev/null && echo running || echo stopped) $(tail -2 "$work/port-forward.log" 2>/dev/null)"
  kubectl -n starfleet get pods -o wide 2>&1 | sed 's/^/--- /'
  kubectl -n starfleet logs deploy/relay --tail=5 2>&1 | sed 's/^/--- relay: /'
  kubectl -n observability logs deploy/jaeger --tail=5 2>&1 | sed 's/^/--- jaeger: /'
  kubectl -n observability get pods -o name 2>&1 | sed 's/^/--- /'
  echo "--- Jaeger services: $(curl -sS --max-time 10 "$api/services" 2>&1)"
  kubectl -n observability logs -l app.kubernetes.io/component=opentelemetry-collector --tail=200 2>&1 | grep -v '	info	' | tail -15 | cut -c1-400 | sed 's/^/--- collector: /'
  kubectl -n observability get endpointslices -o wide 2>&1 | sed 's/^/--- /'
  kubectl -n starfleet get pod -l app=relay -o jsonpath='{range .items[0].spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' 2>&1 | grep OTEL_ | sed 's/^/--- relay env: /'
}

# The helper from the pages, with the port of this test. An optional third
# argument sets the earliest start time (default: any time).
list_spans() {
  forward
  curl -fsS --max-time 10 "$api/traces?query.service_name=$1&query.start_time_min=${3:-2020-01-01T00:00:00Z}&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=${2:-1}" 2>"$work/curl.err" |
    jq -c '.result.resourceSpans[] | (.resource.attributes[] | select(.key=="service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | select(.name != "GET /readyz") | {service: $service, name, traceId, spanId, parentSpanId}'
}
# True when one of the newest 20 relay traces (since the time in $1, if
# given) holds a scout root span whose parent is a relay span. Not only the
# newest: a request starts every 2 seconds and both services send spans in
# batches, so the newest traces are often still missing their scout half.
joined_trace() {
  list_spans relay 20 "${1:-2020-01-01T00:00:00Z}" >"$work/relay-trace.jsonl" 2>/dev/null || return 1
  jq -se '([.[] | select(.service=="relay") | .spanId]) as $relay
    | any(.[]; .service=="scout" and .name=="GET /" and (.parentSpanId as $p | $relay | index($p)))' \
    "$work/relay-trace.jsonl" >/dev/null
}

# Part 010: a trace that starts too late
for _ in $(seq 1 60); do curl -fsS "$api/services" 2>/dev/null | grep -q '"scout"' && break; sleep 3; done
check "only scout sends spans at start" "curl -fsS $api/services | jq -e '(.services | index(\"scout\")) and (.services | index(\"relay\") | not)' >/dev/null"
scout_root() { list_spans scout 20 >"$work/scout.jsonl" 2>/dev/null && jq -se 'any(.[]; .name=="GET /" and .parentSpanId==null)' "$work/scout.jsonl" >/dev/null; }
for _ in $(seq 1 20); do scout_root && break; sleep 3; done
check "scout root span has no parent" "scout_root" || { cat "$work/scout.jsonl"; trace_debug; }

# Part 010: create the Instrumentation and annotate the pod template
from_page course-010-what-the-operator-injects-into-a-pod.md instrumentation-nodejs.yaml
from_page course-010-what-the-operator-injects-into-a-pod.md relay-patch.yaml
check "Instrumentation applied" "kubectl apply -f $work/instrumentation-nodejs.yaml >/dev/null"
check "running relay pod unchanged" "[ -z \"\$(relay_init)\" ]"
check "relay patched" "kubectl -n starfleet patch deployment relay --patch-file $work/relay-patch.yaml >/dev/null"
check "relay rolled out" "relay_rolled_out"
check "init container injected ($(relay_init))" "[ \"\$(relay_init)\" = opentelemetry-auto-instrumentation-nodejs ]"
check "OTEL_SERVICE_NAME=relay" "[ \"\$(relay_env OTEL_SERVICE_NAME)\" = relay ]"
check "OTEL_EXPORTER_OTLP_ENDPOINT from the Instrumentation" "[ \"\$(relay_env OTEL_EXPORTER_OTLP_ENDPOINT)\" = http://otel-collector.observability:4318 ]"
check "OTEL_PROPAGATORS=tracecontext,baggage" "[ \"\$(relay_env OTEL_PROPAGATORS)\" = tracecontext,baggage ]"
check "NODE_OPTIONS loads the agent" "relay_env NODE_OPTIONS | grep -q 'otel-auto-instrumentation-nodejs/autoinstrumentation.js'"

# Part 020: one trace across two services
# On a GitHub runner the Node.js agent of a new relay pod sometimes sends its
# first spans only after one to three minutes (seen 2026-11-09; the spans do
# arrive later), so the relay waits allow four minutes.
for _ in $(seq 1 80); do joined_trace && break; sleep 3; done
check "relay and scout in one trace" "joined_trace" || { cat "$work/relay-trace.jsonl"; trace_debug; }

slow_trace() {
  curl -fsS "$api/traces?query.service_name=relay&query.start_time_min=2020-01-01T00:00:00Z&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=1&query.duration_min=500ms" |
    jq -c '.result.resourceSpans[] | (.resource.attributes[] | select(.key=="service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | {service: $service, name, kind, ms: (((.endTimeUnixNano|tonumber) - (.startTimeUnixNano|tonumber)) / 1000000 | round)}'
}
for _ in $(seq 1 20); do slow_trace 2>/dev/null | grep -q delayHandler && break; sleep 3; done
check "slow trace: delayHandler in scout about 1000 ms" "slow_trace | jq -se 'any(.[]; .service==\"scout\" and .name==\"delayHandler\" and .ms >= 900 and .ms <= 1300)' >/dev/null"

# Part 030: break and restore context propagation
from_page course-030-breaking-and-restoring-context-propagation.md instrumentation-nodejs-baggage.yaml
check "baggage-only Instrumentation applied" "kubectl apply -f $work/instrumentation-nodejs-baggage.yaml >/dev/null"
check "running pod keeps tracecontext,baggage" "[ \"\$(relay_env OTEL_PROPAGATORS)\" = tracecontext,baggage ]"
kubectl -n starfleet rollout restart deployment/relay >/dev/null
check "relay restarted" "relay_rolled_out"
check "new pod has OTEL_PROPAGATORS=baggage" "[ \"\$(relay_env OTEL_PROPAGATORS)\" = baggage ]"
# Only traces that start after the old pod is gone count: the old pod's last
# batches still arrive after the restart and hold scout spans.
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
wait_secs 20
# At least one relay trace since then, and none of them holds a scout span.
relay_alone() { list_spans relay 5 "$since" >"$work/relay-alone.jsonl" 2>/dev/null && jq -se 'length > 0 and all(.[]; .service=="relay")' "$work/relay-alone.jsonl" >/dev/null; }
for _ in $(seq 1 80); do relay_alone && break; sleep 3; done
check "relay trace has no scout span" "relay_alone" || { cat "$work/relay-alone.jsonl"; trace_debug; }

check "Instrumentation restored" "kubectl apply -f $work/instrumentation-nodejs.yaml >/dev/null"
kubectl -n starfleet rollout restart deployment/relay >/dev/null
check "relay restarted" "relay_rolled_out"
check "restored pod has OTEL_PROPAGATORS=tracecontext,baggage" "[ \"\$(relay_env OTEL_PROPAGATORS)\" = tracecontext,baggage ]"

# Part 040: the annotation on the wrong object
from_page course-040-finding-why-a-pod-is-not-instrumented.md relay-misplaced-annotation.yaml
check "misplaced annotation patched" "kubectl -n starfleet patch deployment relay --patch-file $work/relay-misplaced-annotation.yaml >/dev/null"
check "relay rolled out" "relay_rolled_out"
check "no init container" "[ -z \"\$(relay_init)\" ]"
check "annotation on Deployment, null on template" "[ \"\$(kubectl -n starfleet get deployment relay -o json | jq -c '{deployment: .metadata.annotations[\"instrumentation.opentelemetry.io/inject-nodejs\"], pod_template: .spec.template.metadata.annotations[\"instrumentation.opentelemetry.io/inject-nodejs\"]}')\" = '{\"deployment\":\"true\",\"pod_template\":null}' ]"

# Part 040: the Instrumentation that is not found
from_page course-040-finding-why-a-pod-is-not-instrumented.md relay-annotate-template.yaml
check "Instrumentation deleted" "kubectl -n starfleet delete instrumentation nodejs >/dev/null"
check "template annotation patched" "kubectl -n starfleet patch deployment relay --patch-file $work/relay-annotate-template.yaml >/dev/null"
check "relay rolled out" "relay_rolled_out"
check "still no init container" "[ -z \"\$(relay_init)\" ]"
check "Operator log says failed to select" "kubectl -n opentelemetry-operator-system logs deploy/opentelemetry-operator-controller-manager | grep 'failed to select' | tail -1 | jq -e 'select(.namespace==\"starfleet\" and .error==\"no OpenTelemetry Instrumentation instances available\")' >/dev/null"

check "Instrumentation created again" "kubectl apply -f $work/instrumentation-nodejs.yaml >/dev/null"
check "running pod stays without agent" "[ -z \"\$(relay_init)\" ]"
kubectl -n starfleet rollout restart deployment/relay >/dev/null
check "relay restarted" "relay_rolled_out"
check "init container back" "[ \"\$(relay_init)\" = opentelemetry-auto-instrumentation-nodejs ]"
check "new pod has OTEL_PROPAGATORS=tracecontext,baggage" "[ \"\$(relay_env OTEL_PROPAGATORS)\" = tracecontext,baggage ]"
# Only traces from the new pod count.
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
wait_secs 20
for _ in $(seq 1 80); do joined_trace "$since" && break; sleep 3; done
check "relay and scout in one trace again" "joined_trace $since" || { cat "$work/relay-trace.jsonl"; trace_debug; }

[ "$failed" -eq 0 ] && echo "smoke test passed" || echo "smoke test FAILED"
exit "$failed"

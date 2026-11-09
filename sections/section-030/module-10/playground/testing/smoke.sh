#!/usr/bin/env bash
# Smoke test for ats-020-playground-030-01, run by scripts/ci/test-playground.sh
# against a fresh playground (KUBECONFIG points at it). It runs the commands
# the module pages teach and checks the results the pages show:
#   - the Operator, its certificate and its four resource types are ready;
#   - the Collector from the Collector part starts and scout spans reach Jaeger;
#   - probe starts healthy, fails when TARGET_URL names a missing Service,
#     its exception events can be exported, and the fix gives clean spans.
# It changes only the playground cluster. Exit code 0 means every check passed.
set -uo pipefail

module=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
port=16686
failed=0

check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; failed=1; fi; }
wait_secs() { local start; start=$(date +%s); until [ $(( $(date +%s) - start )) -ge "$1" ]; do sleep 2; done; }
cleanup() { [ -n "${forward_pid:-}" ] && kill "$forward_pid" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

# The Operator and its webhook
check "operator rolled out" "kubectl -n opentelemetry-operator-system rollout status deployment/opentelemetry-operator-controller-manager --timeout=120s >/dev/null"
check "webhook certificate ready" "[ \"\$(kubectl -n opentelemetry-operator-system get certificate opentelemetry-operator-serving-cert -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}')\" = True ]"
check "4 opentelemetry.io resource types" "[ \$(kubectl api-resources --api-group=opentelemetry.io --no-headers | wc -l) -eq 4 ]"

# The Collector, with the YAML exactly as the page shows it
awk '/Save this as `opentelemetrycollector-otel.yaml`/{f=1;next} f&&/^```yaml/{g=1;next} g&&/^```/{exit} g' \
  "$module/course-020-a-collector-with-an-otlp-receiver-and-a-jaeger-exporter.md" >"$work/otel.yaml"
check "Collector YAML found on the page" "[ -s $work/otel.yaml ]"
check "Collector applied" "kubectl apply -f $work/otel.yaml >/dev/null"
check "Collector rolled out" "for i in \$(seq 1 30); do kubectl -n observability get deploy otel-collector >/dev/null 2>&1 && break; sleep 2; done; kubectl -n observability rollout status deploy/otel-collector --timeout=180s >/dev/null"

kubectl -n observability port-forward svc/jaeger "$port:16686" >/dev/null 2>&1 &
forward_pid=$!
api=http://127.0.0.1:$port/api/v3
for _ in $(seq 1 60); do curl -fsS "$api/services" 2>/dev/null | grep -q '"scout"' && break; sleep 3; done
check "scout and probe in Jaeger" "curl -fsS $api/services | jq -e '.services | index(\"scout\") and index(\"probe\")' >/dev/null"

count_error_spans() {
  curl -fsSG "$api/traces" \
    --data-urlencode "query.serviceName=$1" \
    --data-urlencode 'query.startTimeMin=2020-01-01T00:00:00Z' \
    --data-urlencode 'query.startTimeMax=2100-01-01T00:00:00Z' \
    --data-urlencode "query.searchDepth=${2:-20}" |
    jq '[.result.resourceSpans[].scopeSpans[].spans[] | select((.status.code // 0) as $code | $code == 2 or $code == "STATUS_CODE_ERROR")] | length'
}
# A count must be a number: an empty answer is a failed request, not zero.
is_count() { [[ "$1" =~ ^[0-9]+$ ]]; }

# Failed spans and exception events
# probe starts together with scout, so its first calls can fail before the
# scout endpoint is ready. Wait until the newest 3 probe traces are clean.
for _ in $(seq 1 20); do
  start_count=$(count_error_spans probe 3)
  is_count "$start_count" && [ "$start_count" -eq 0 ] && break
  sleep 3
done
check "probe healthy at start (count: $start_count)" "is_count '$start_count' && [ '$start_count' -eq 0 ]"

kubectl -n starfleet set env deployment/probe TARGET_URL=http://relay.starfleet:8080 >/dev/null
kubectl -n starfleet rollout status deployment/probe --timeout=120s >/dev/null
wait_secs 20
probe_count=$(count_error_spans probe)
scout_count=$(count_error_spans scout)
check "probe has error spans (count: $probe_count)" "is_count '$probe_count' && [ '$probe_count' -gt 0 ]"
check "scout has none (count: $scout_count)" "is_count '$scout_count' && [ '$scout_count' -eq 0 ]"

curl -fsSG "$api/traces" \
  --data-urlencode 'query.serviceName=probe' \
  --data-urlencode 'query.startTimeMin=2020-01-01T00:00:00Z' \
  --data-urlencode 'query.startTimeMax=2100-01-01T00:00:00Z' \
  --data-urlencode 'query.searchDepth=5' |
  jq '[.result.resourceSpans[].scopeSpans[].spans[] | select((.status.code // 0) as $code | $code == 2 or $code == "STATUS_CODE_ERROR") | .events[]? | select(.name == "exception")]' >"$work/probe-exceptions.json"
check "exception events exported" "[ \$(jq length $work/probe-exceptions.json) -ge 1 ]"
check "exception message as on the page" "jq -r '.[] | (.attributes | map({(.key): .value.stringValue}) | add) | \"\(.[\"exception.type\"]): \(.[\"exception.message\"])\"' $work/probe-exceptions.json | grep -q 'URLError: <urlopen error \[Errno -2\] Name does not resolve>'"

kubectl -n starfleet set env deployment/probe TARGET_URL=http://scout.starfleet:9898/ >/dev/null
kubectl -n starfleet rollout status deployment/probe --timeout=120s >/dev/null
wait_secs 20
fixed_count=$(count_error_spans probe 3)
check "probe fixed, newest 3 traces clean (count: $fixed_count)" "is_count '$fixed_count' && [ '$fixed_count' -eq 0 ]"

[ "$failed" -eq 0 ] && echo "smoke test passed" || echo "smoke test FAILED"
exit "$failed"

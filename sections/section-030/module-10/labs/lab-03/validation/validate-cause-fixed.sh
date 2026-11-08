#!/usr/bin/env bash
# Grader: the Deployment probe calls the Service that exists, its rollout is
# done, and the traces its new pod sends have no error status. The service
# name and the other variables must stay as they were.
set -uo pipefail
api=/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces
fail() { echo "FAIL: cause-fixed: $*" >&2; exit 1; }
errored='(.status.code // 0) as $code | ($code == 2 or $code == "STATUS_CODE_ERROR")'

kubectl -n starfleet rollout status deploy/probe --timeout=90s >/dev/null 2>&1 || fail "the Deployment probe did not finish its rollout"
kubectl -n starfleet get deploy probe -o json | jq -e '
  .metadata.generation <= .status.observedGeneration and
  .spec.replicas == 1 and .status.updatedReplicas == 1 and .status.readyReplicas == 1 and
  any(.spec.template.spec.containers[];
    .name == "probe" and
    any(.env[]; .name == "TARGET_URL" and .value == "http://shuttle.starfleet:8080") and
    any(.env[]; .name == "TRACE_SERVICE" and .value == "probe"))
' >/dev/null 2>&1 || fail "the Deployment probe must run one ready replica with TARGET_URL=http://shuttle.starfleet:8080 and TRACE_SERVICE unchanged"

# Only traces from the new pod count, so search from the time it started.
pod_started="$(kubectl -n starfleet get pods -l app=probe -o json 2>/dev/null |
  jq -r '[.items[] | select(.metadata.deletionTimestamp == null)] | sort_by(.status.startTime) | last | .status.startTime // empty')"
[ -n "$pod_started" ] || fail "no running pod of probe was found"
for attempt in $(seq 1 18); do
  response="$(kubectl get --raw "$api?query.serviceName=probe&query.startTimeMin=$pod_started&query.startTimeMax=2100-01-01T00:00:00Z&query.searchDepth=20" 2>/dev/null || true)"
  if jq -e "
    [.result.resourceSpans[]?.scopeSpans[]?.spans[]?] as \$spans |
    (\$spans | map(.traceId) | unique) as \$traces |
    (\$spans | map(select($errored) | .traceId) | unique) as \$errored_traces |
    (\$traces - \$errored_traces | length) >= 1
  " <<<"$response" >/dev/null 2>&1; then
    echo "PASS: cause-fixed"
    exit 0
  fi
  sleep 5
done
fail "the new pod of probe sent no trace without an error status within 90 seconds; check that TARGET_URL names the Service shuttle on port 8080"

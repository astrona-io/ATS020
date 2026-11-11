#!/usr/bin/env bash
# Grader: the RUNNING probe pod requests at least its measured peak memory
# (it asked for 2Mi and uses more), with a bounded request and a memory limit.
#
#   memory: request >= peak and <= max(4 x peak, 100Mi)
#   cpu:    request must be set and at most max(4 x peak, 20m)
#   limit:  memory limit must exist and be at least the request and the peak
# Wrong fixes rejected: leaving 2Mi, deleting the limit, setting a huge request.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): replicas, readiness
# and restarts are unchanged and scout still answers 200 to shuttle.
check_deployment() {
  local name="$1" want="$2" json
  json="$(kubectl -n starfleet get deployment "$name" -o json 2>/dev/null)" || fail "Deployment $name is missing"
  local spec ready updated gen observed
  spec="$(printf '%s' "$json" | jq '.spec.replicas')"
  ready="$(printf '%s' "$json" | jq '.status.readyReplicas // 0')"
  updated="$(printf '%s' "$json" | jq '.status.updatedReplicas // 0')"
  gen="$(printf '%s' "$json" | jq '.metadata.generation')"
  observed="$(printf '%s' "$json" | jq '.status.observedGeneration // 0')"
  [ "$spec" = "$want" ] || fail "Deployment $name has $spec replicas, expected $want"
  [ "$gen" = "$observed" ] || fail "Deployment $name rollout has not been observed yet"
  [ "$updated" = "$want" ] || fail "Deployment $name has $updated updated replicas, expected $want"
  [ "$ready" = "$want" ] || fail "Deployment $name has $ready ready replicas, expected $want"
}

# Allow a rollout that just finished to settle.
for attempt in $(seq 1 24); do
  if (check_deployment scout 2 && check_deployment probe 1) >/dev/null 2>&1; then break; fi
  sleep 5
done
check_deployment scout 2
check_deployment probe 1

CODE=""
for attempt in $(seq 1 12); do
  CODE="$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://scout.starfleet.svc.cluster.local:9898/ 2>/dev/null)"
  [ "$CODE" = "200" ] && break
  sleep 5
done
[ "$CODE" = "200" ] || fail "shuttle gets '${CODE:-no answer}' from scout, expected 200"

prom() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$1" 2>/dev/null \
    | jq -r '.data.result[0].value[1] // empty' 2>/dev/null
}
to_bytes() {
  awk -v q="$1" 'BEGIN {
    n = q + 0
    if (q ~ /Ki$/) n *= 1024
    else if (q ~ /Mi$/) n *= 1048576
    else if (q ~ /Gi$/) n *= 1073741824
    else if (q ~ /k$/) n *= 1000
    else if (q ~ /M$/) n *= 1000000
    else if (q ~ /G$/) n *= 1000000000
    printf "%d", n
  }'
}
to_cores() {
  awk -v q="$1" 'BEGIN { if (q ~ /m$/) printf "%.4f", q / 1000; else printf "%.4f", q + 0 }'
}

PODS="$(kubectl -n starfleet get pods -l app=probe -o json 2>/dev/null)" || fail "cannot list probe pods"
COUNT="$(printf '%s' "$PODS" | jq '[.items[] | select(.metadata.deletionTimestamp == null)] | length')"
[ "$COUNT" -ge 1 ] || fail "no probe pods"

MEM_PEAK=""
CPU_PEAK=""
for attempt in $(seq 1 24); do
  MEM_PEAK="$(prom 'max(max_over_time(container_memory_working_set_bytes%7Bnamespace%3D%22starfleet%22%2Ccontainer%3D%22probe%22%7D%5B1h%5D))')"
  CPU_PEAK="$(prom 'max(max_over_time(rate(container_cpu_usage_seconds_total%7Bnamespace%3D%22starfleet%22%2Ccontainer%3D%22probe%22%7D%5B2m%5D)%5B1h%3A30s%5D))')"
  [ -n "$MEM_PEAK" ] && break
  sleep 5
done
# A container that barely uses CPU can return no CPU series: treat it as 0.
CPU_PEAK="${CPU_PEAK:-0}"
[ -n "$MEM_PEAK" ] || fail "Prometheus has no usage data for probe yet"

while IFS=$'\t' read -r POD REQ_MEM REQ_CPU LIM_MEM RESTARTS OOM; do
  [ -n "$REQ_MEM" ] || fail "pod $POD has no memory request"
  [ -n "$REQ_CPU" ] || fail "pod $POD has no CPU request"
  [ -n "$LIM_MEM" ] || fail "pod $POD has no memory limit (keep a limit, size it, do not remove it)"
  RM="$(to_bytes "$REQ_MEM")"; RC="$(to_cores "$REQ_CPU")"; LM="$(to_bytes "$LIM_MEM")"
  awk -v r="$RM" -v p="$MEM_PEAK" 'BEGIN {exit !(r >= p)}' \
    || fail "pod $POD requests $REQ_MEM, below the measured peak of $(awk -v p="$MEM_PEAK" 'BEGIN {printf "%.1f", p/1048576}')Mi"
  awk -v r="$RM" -v p="$MEM_PEAK" 'BEGIN {m = 4*p; if (m < 104857600) m = 104857600; exit !(r <= m)}' \
    || fail "pod $POD requests $REQ_MEM, far above the measured peak (limit for a pass: 4 x peak or 100Mi)"
  awk -v r="$RC" -v p="$CPU_PEAK" 'BEGIN {m = 4*p; if (m < 0.02) m = 0.02; exit !(r > 0 && r <= m)}' \
    || fail "pod $POD requests CPU $REQ_CPU, outside the allowed range (more than 0, at most 4 x peak or 20m)"
  awk -v l="$LM" -v r="$RM" -v p="$MEM_PEAK" 'BEGIN {exit !(l >= r && l >= p)}' \
    || fail "pod $POD has memory limit $LIM_MEM, below its request or the measured peak"
  [ "${RESTARTS:-0}" = "0" ] || fail "pod $POD restarted $RESTARTS times"
  [ "$OOM" != "OOMKilled" ] || fail "pod $POD was OOMKilled"
done < <(printf '%s' "$PODS" | jq -r '.items[] | select(.metadata.deletionTimestamp == null) | [
  .metadata.name,
  (.spec.containers[] | select(.name == "probe") | .resources.requests.memory // ""),
  (.spec.containers[] | select(.name == "probe") | .resources.requests.cpu // ""),
  (.spec.containers[] | select(.name == "probe") | .resources.limits.memory // ""),
  ((.status.containerStatuses // [])[0].restartCount // 0 | tostring),
  ((.status.containerStatuses // [])[0].lastState.terminated.reason // "")
] | @tsv')

echo "PASS: probe requests at least its measured peak memory ($(awk -v p="$MEM_PEAK" 'BEGIN {printf "%.1f", p/1048576}')Mi) and keeps a memory limit"

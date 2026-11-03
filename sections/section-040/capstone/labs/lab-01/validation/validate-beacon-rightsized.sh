#!/usr/bin/env bash
# Grader: the RUNNING beacon pod (not only the Deployment) requests memory and
# CPU close to the measured peak usage, and keeps a memory limit.
#
# Peak usage comes from Prometheus over the last hour, across every beacon pod
# (old pods count too):
#   memory: request below the peak is a fail, above max(4 x peak, 100Mi) is a fail
#   cpu:    request must be set and at most max(4 x peak, 20m)
#   limit:  memory limit must exist and be at least the request and the peak
# Wrong fixes rejected: leaving 600m / 768Mi, deleting requests or limits,
# setting requests below the real usage.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

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

# Allow a rollout that just finished to settle.
for attempt in $(seq 1 24); do
  PODS="$(kubectl -n starfleet get pods -l app=beacon -o json 2>/dev/null)" || fail "cannot list beacon pods"
  COUNT="$(printf '%s' "$PODS" | jq '[.items[] | select(.metadata.deletionTimestamp == null)] | length')"
  READY="$(printf '%s' "$PODS" | jq '[.items[] | select(.metadata.deletionTimestamp == null) | select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))] | length')"
  [ "$COUNT" = "1" ] && [ "$READY" = "1" ] && break
  sleep 5
done
[ "$COUNT" = "1" ] || fail "beacon has $COUNT running pods, expected 1 (do not change the replicas)"
[ "$READY" = "1" ] || fail "the beacon pod is not ready"

MEM_PEAK=""
CPU_PEAK=""
for attempt in $(seq 1 24); do
  MEM_PEAK="$(prom 'max(max_over_time(container_memory_working_set_bytes%7Bnamespace%3D%22starfleet%22%2Ccontainer%3D%22beacon%22%7D%5B1h%5D))')"
  CPU_PEAK="$(prom 'max(max_over_time(rate(container_cpu_usage_seconds_total%7Bnamespace%3D%22starfleet%22%2Ccontainer%3D%22beacon%22%7D%5B2m%5D)%5B1h%3A30s%5D))')"
  [ -n "$MEM_PEAK" ] && break
  sleep 5
done
# A container that barely uses CPU can return no CPU series: treat it as 0.
CPU_PEAK="${CPU_PEAK:-0}"
[ -n "$MEM_PEAK" ] || fail "Prometheus has no usage data for beacon yet"

while IFS=$'\t' read -r POD REQ_MEM REQ_CPU LIM_MEM RESTARTS OOM; do
  [ -n "$REQ_MEM" ] || fail "pod $POD has no memory request"
  [ -n "$REQ_CPU" ] || fail "pod $POD has no CPU request"
  [ -n "$LIM_MEM" ] || fail "pod $POD has no memory limit (keep a limit, size it, do not remove it)"
  RM="$(to_bytes "$REQ_MEM")"; RC="$(to_cores "$REQ_CPU")"; LM="$(to_bytes "$LIM_MEM")"
  awk -v r="$RM" -v p="$MEM_PEAK" 'BEGIN {exit !(r >= p)}' \
    || fail "pod $POD requests $REQ_MEM, below the measured peak of $(awk -v p="$MEM_PEAK" 'BEGIN {printf "%.0f", p/1048576}')Mi"
  awk -v r="$RM" -v p="$MEM_PEAK" 'BEGIN {m = 4*p; if (m < 104857600) m = 104857600; exit !(r <= m)}' \
    || fail "pod $POD requests $REQ_MEM, far above the measured peak of $(awk -v p="$MEM_PEAK" 'BEGIN {printf "%.0f", p/1048576}')Mi (limit for a pass: 4 x peak or 100Mi)"
  awk -v r="$RC" -v p="$CPU_PEAK" 'BEGIN {m = 4*p; if (m < 0.02) m = 0.02; exit !(r > 0 && r <= m)}' \
    || fail "pod $POD requests CPU $REQ_CPU, outside the allowed range (more than 0, at most 4 x peak or 20m)"
  awk -v l="$LM" -v r="$RM" -v p="$MEM_PEAK" 'BEGIN {exit !(l >= r && l >= p)}' \
    || fail "pod $POD has memory limit $LIM_MEM, below its request or the measured peak"
  [ "${RESTARTS:-0}" = "0" ] || fail "pod $POD restarted $RESTARTS times"
  [ "$OOM" != "OOMKilled" ] || fail "pod $POD was OOMKilled"
done < <(printf '%s' "$PODS" | jq -r '.items[] | select(.metadata.deletionTimestamp == null) | [
  .metadata.name,
  (.spec.containers[] | select(.name == "beacon") | .resources.requests.memory // ""),
  (.spec.containers[] | select(.name == "beacon") | .resources.requests.cpu // ""),
  (.spec.containers[] | select(.name == "beacon") | .resources.limits.memory // ""),
  ((.status.containerStatuses // [])[0].restartCount // 0 | tostring),
  ((.status.containerStatuses // [])[0].lastState.terminated.reason // "")
] | @tsv')

echo "PASS: beacon requests close to the measured peak (memory peak $(awk -v p="$MEM_PEAK" 'BEGIN {printf "%.0f", p/1048576}')Mi, CPU peak $(awk -v p="$CPU_PEAK" 'BEGIN {printf "%.1f", p*1000}')m)"

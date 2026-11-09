#!/usr/bin/env bash
# Grader: cargo has a memory limit that fits its use. A limit must exist (the
# plausible wrong fix removes it) and must be between 256Mi and 1Gi (the
# process holds about 150Mi plus the runtime, and a huge limit is no sizing).
# The running pod must not have an OOMKilled restart, and shuttle gets a 200.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

IMAGE="$(kubectl -n starfleet get deployment cargo -o jsonpath='{.spec.template.spec.containers[?(@.name=="cargo")].image}' 2>/dev/null)" \
  || fail "Deployment cargo is missing in namespace starfleet (fix it, do not delete it)"
[ "$IMAGE" = "node:22-alpine" ] || fail "cargo image is '$IMAGE', expected node:22-alpine"

LIMIT="$(kubectl -n starfleet get deployment cargo -o jsonpath='{.spec.template.spec.containers[?(@.name=="cargo")].resources.limits.memory}' 2>/dev/null)"
[ -n "$LIMIT" ] || fail "cargo has no memory limit. Do not remove the limit: set one that fits the use of the process"

BYTES="$(python3 - "$LIMIT" <<'PY'
import sys
v = sys.argv[1]
units = {"Ki": 2**10, "Mi": 2**20, "Gi": 2**30, "K": 10**3, "M": 10**6, "G": 10**9}
for suffix, factor in sorted(units.items(), key=lambda kv: -len(kv[0])):
    if v.endswith(suffix):
        print(int(float(v[: -len(suffix)]) * factor)); break
else:
    print(int(float(v)))
PY
)"
[ "$BYTES" -ge $((256 * 1024 * 1024)) ] || fail "the memory limit of cargo is $LIMIT; the process needs more than that (read the last state and kubectl top)"
[ "$BYTES" -lt $((1024 * 1024 * 1024)) ] || fail "the memory limit of cargo is $LIMIT; keep it below 1Gi"

for attempt in $(seq 1 36); do
  READY="$(kubectl -n starfleet get deployment cargo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "${READY:-0}" -ge 1 ] && break
  sleep 5
done
[ "${READY:-0}" -ge 1 ] || fail "cargo has no Ready pod"

PODS="$(kubectl -n starfleet get pods -l app=cargo -o json)"
printf '%s' "$PODS" | jq -e '[.items[] | select(.metadata.deletionTimestamp == null)] | length == 1' >/dev/null || fail "wait for the cargo rollout to finish"
REASON="$(printf '%s' "$PODS" | jq -r '.items[] | select(.metadata.deletionTimestamp == null) | .status.containerStatuses[0].lastState.terminated.reason // empty')"
[ "$REASON" != "OOMKilled" ] || fail "the running cargo pod was OOMKilled before; the limit is still too low"

# cargo has no readiness probe, so the pod is Ready before the Node.js process
# listens; give the process and the Service endpoint a minute to settle.
CODE=""
for attempt in $(seq 1 12); do
  CODE="$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://cargo:8080/ 2>/dev/null)"
  [ "$CODE" = "200" ] && break
  sleep 5
done
[ "$CODE" = "200" ] || fail "shuttle got '$CODE' from http://cargo:8080/, expected 200"

echo "PASS: cargo has a memory limit of $LIMIT, is Ready and answers 200"

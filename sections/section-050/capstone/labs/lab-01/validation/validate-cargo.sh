#!/usr/bin/env bash
# Grader: cargo has a memory limit that fits its use. A limit must exist (the
# plausible wrong fix removes it) and must be between 256Mi and 1Gi (the
# process holds about 150Mi plus the runtime, and a huge limit is no sizing).
# The running pod must not have an OOMKilled restart, and shuttle gets a 200.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): the workloads, the
# webhook configuration, the webhook server and shuttle are still in place.
SHUTTLE_IMAGE="$(kubectl -n starfleet get deployment shuttle -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)" \
  || fail "Deployment shuttle is missing in namespace starfleet"
[ "$SHUTTLE_IMAGE" = "curlimages/curl:8.23.0" ] || fail "shuttle image changed to '$SHUTTLE_IMAGE'"

for name in probe cargo beacon; do
  REPLICAS="$(kubectl -n starfleet get deployment "$name" -o jsonpath='{.spec.replicas}' 2>/dev/null)" \
    || fail "Deployment $name is missing in namespace starfleet"
  [ "$REPLICAS" = "1" ] || fail "Deployment $name has $REPLICAS replicas, expected 1 (do not scale a workload to zero)"
  kubectl -n starfleet get service "$name" >/dev/null 2>&1 || fail "Service $name is missing in namespace starfleet"
done

CARGO_COMMAND="$(kubectl -n starfleet get deployment cargo -o jsonpath='{.spec.template.spec.containers[0].command[*]}' 2>/dev/null)"
case "$CARGO_COMMAND" in *"Buffer.alloc"*) ;; *) fail "the command of cargo was changed; size the memory limit instead";; esac

kubectl -n webhook-system get deployment starfleet-policy >/dev/null 2>&1 || fail "the webhook server starfleet-policy is missing"
kubectl -n webhook-system get service starfleet-policy >/dev/null 2>&1 || fail "the Service starfleet-policy is missing"
WEBHOOKS="$(kubectl get validatingwebhookconfiguration starfleet-policy -o jsonpath='{.webhooks[0].rules[0].resources[0]}' 2>/dev/null)"
[ "$WEBHOOKS" = "deployments" ] || fail "the webhook configuration starfleet-policy was changed or deleted"

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
[ "$BYTES" -le $((1024 * 1024 * 1024)) ] || fail "the memory limit of cargo is $LIMIT; that is too large to be sized to the use (expected at most 1Gi)"

for attempt in $(seq 1 36); do
  READY="$(kubectl -n starfleet get deployment cargo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  [ "${READY:-0}" -ge 1 ] && break
  sleep 5
done
[ "${READY:-0}" -ge 1 ] || fail "cargo has no Ready pod"

REASON="$(kubectl -n starfleet get pods -l app=cargo --field-selector status.phase=Running -o jsonpath='{.items[0].status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)"
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

#!/usr/bin/env bash
# Grader: the fix keeps the design. shuttle is untouched, probe, cargo and beacon
# keep one replica and their Services, the webhook configuration and the webhook
# server are still in place, and the command of cargo is unchanged.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

SHUTTLE_IMAGE="$(kubectl -n starfleet get deployment shuttle -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)" \
  || fail "Deployment shuttle is missing in namespace starfleet"
[ "$SHUTTLE_IMAGE" = "curlimages/curl:8.22.0" ] || fail "shuttle image changed to '$SHUTTLE_IMAGE'"

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

echo "PASS: the workloads, the webhook and shuttle are unchanged in design"

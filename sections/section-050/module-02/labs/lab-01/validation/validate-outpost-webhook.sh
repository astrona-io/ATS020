#!/usr/bin/env bash
# Grader: a Deployment can be created in outpost, and the outpost-policy
# webhook server really answered the request. The webhook configuration must
# still point at the Service outpost-policy with failurePolicy Fail, so
# deleting it or setting failurePolicy: Ignore does not pass (the server log
# must show a new allowed request). Retries, because endpoints update late.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
count_answers() { kubectl -n webhook-system logs -l app=outpost-policy --tail=-1 2>/dev/null | grep -c ' allowed' || true; }

kubectl get validatingwebhookconfiguration outpost-policy >/dev/null 2>&1 \
  || fail "the ValidatingWebhookConfiguration outpost-policy is missing (fix the cause, do not delete it)"
POLICY="$(kubectl get validatingwebhookconfiguration outpost-policy -o jsonpath='{.webhooks[0].failurePolicy}')"
[ "$POLICY" = "Fail" ] || fail "failurePolicy of outpost-policy is '$POLICY', expected Fail"
SERVICE="$(kubectl get validatingwebhookconfiguration outpost-policy -o jsonpath='{.webhooks[0].clientConfig.service.name}')"
[ "$SERVICE" = "outpost-policy" ] || fail "the webhook calls Service '$SERVICE', expected outpost-policy"

BEFORE="$(count_answers)"
CREATED=""
for attempt in $(seq 1 18); do
  if kubectl -n outpost create deployment grader-check --image=ghcr.io/stefanprodan/podinfo:6.15.0 >/dev/null 2>&1; then
    CREATED=yes
    break
  fi
  sleep 5
done
[ -n "$CREATED" ] || fail "creating a Deployment in outpost still fails: $(kubectl -n outpost create deployment grader-check --image=ghcr.io/stefanprodan/podinfo:6.15.0 2>&1 | tail -1)"
kubectl -n outpost delete deployment grader-check --wait=false >/dev/null 2>&1

AFTER="$(count_answers)"
[ "${AFTER:-0}" -gt "${BEFORE:-0}" ] || fail "the outpost-policy server did not log a new request: the webhook was not called"

echo "PASS: a Deployment can be created in outpost and the webhook server answered"

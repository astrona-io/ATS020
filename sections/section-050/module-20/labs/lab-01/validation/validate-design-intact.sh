#!/usr/bin/env bash
# Grader: the fix keeps the design. Both webhook configurations still exist with
# failurePolicy Fail and still call their own Service. The workloads, the
# ServiceMonitor, the PrometheusRule and the operator Deployment are in place.
# A fix that deletes or weakens a webhook or deletes the monitoring objects does
# not pass.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

for name in starfleet-policy outpost-policy; do
  kubectl get validatingwebhookconfiguration "$name" >/dev/null 2>&1 || fail "the ValidatingWebhookConfiguration $name is missing"
  POLICY="$(kubectl get validatingwebhookconfiguration "$name" -o jsonpath='{.webhooks[0].failurePolicy}')"
  [ "$POLICY" = "Fail" ] || fail "failurePolicy of $name is '$POLICY', expected Fail"
  SERVICE="$(kubectl get validatingwebhookconfiguration "$name" -o jsonpath='{.webhooks[0].clientConfig.service.name}')"
  [ "$SERVICE" = "$name" ] || fail "the webhook $name calls Service '$SERVICE', expected $name"
  RESOURCES="$(kubectl get validatingwebhookconfiguration "$name" -o jsonpath='{.webhooks[0].rules[0].resources[0]}')"
  [ "$RESOURCES" = "deployments" ] || fail "the rule of $name no longer matches deployments"
  kubectl -n webhook-system get deployment "$name" >/dev/null 2>&1 || fail "the Deployment $name is missing in webhook-system"
  kubectl -n webhook-system get service "$name" >/dev/null 2>&1 || fail "the Service $name is missing in webhook-system"
done

for target in "starfleet deployment shuttle" "starfleet deployment scout" "outpost deployment drifter" \
              "starfleet servicemonitor scout" "starfleet prometheusrule scout-alerts" \
              "monitoring deployment kps-operator" "monitoring prometheus kps-prometheus"; do
  set -- $target
  kubectl -n "$1" get "$2" "$3" >/dev/null 2>&1 || fail "$2 $3 is missing in namespace $1"
done

echo "PASS: both webhooks keep failurePolicy Fail and the workloads and monitoring objects are in place"

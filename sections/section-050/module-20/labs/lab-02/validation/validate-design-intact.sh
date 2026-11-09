#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
kubectl get validatingwebhookconfiguration outpost-policy -o json | jq -e '
  .webhooks[0] | .failurePolicy == "Fail" and .clientConfig.service.name == "outpost-policy"
  and .clientConfig.service.namespace == "webhook-system"
  and (.rules[0].resources | index("deployments")) != null
  and .namespaceSelector.matchLabels["kubernetes.io/metadata.name"] == "outpost"
' >/dev/null || fail 'the webhook configuration was removed or bypassed'
expected=$(kubectl -n webhook-system get secret webhook-ca -o jsonpath='{.data.tls\.crt}')
actual=$(kubectl get validatingwebhookconfiguration outpost-policy -o jsonpath='{.webhooks[0].clientConfig.caBundle}')
[ "$actual" = "$expected" ] || fail 'the trusted CA was changed'
kubectl -n webhook-system get deployment outpost-policy >/dev/null
kubectl -n webhook-system get service outpost-policy >/dev/null
echo 'PASS: the webhook still enforces admission with its original CA'

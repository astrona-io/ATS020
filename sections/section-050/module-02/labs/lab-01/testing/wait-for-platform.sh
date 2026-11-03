#!/usr/bin/env bash
# Helper for `astrona test`: waits until both webhook servers and the Prometheus
# Operator are ready, so the validation scripts do not start while pods are replaced.
set -uo pipefail

for name in starfleet-policy outpost-policy; do
  kubectl -n webhook-system rollout status "deployment/$name" --timeout=180s
done
kubectl -n monitoring rollout status deployment/kps-operator --timeout=180s
echo "[testing] the webhook servers and the operator are ready."
exit 0

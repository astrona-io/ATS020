#!/usr/bin/env bash
# OS prep for the "Run An OpenTelemetry Collector With The Operator"
# playground (`ats-020-playground-030-01`).
#
# Environment preparation only; there is no task and no grading. This script
# installs cert-manager 1.21.2 and waits until its webhook answers, because
# the OpenTelemetry Operator, which the reader installs, needs it for its
# webhook certificate. Jaeger and the Starfleet workloads come from
# manifests/lab-start.yaml.
set -euo pipefail

CERT_MANAGER_VERSION="v1.21.2"

echo "[playground] Installing cert-manager ${CERT_MANAGER_VERSION}..."
kubectl apply --server-side -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
for d in cert-manager cert-manager-cainjector cert-manager-webhook; do
  kubectl -n cert-manager rollout status "deployment/$d" --timeout=300s
done
echo "[playground] cert-manager is ready."

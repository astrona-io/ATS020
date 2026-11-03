#!/usr/bin/env bash
# OS prep for the "Add Tracing Without Code Changes Using
# Auto-Instrumentation" playground (`ats-020-playground-030-02`).
#
# Environment preparation only; there is no task and no grading. This script:
#   1. installs cert-manager 1.21.2 and waits for it,
#   2. installs the OpenTelemetry Operator 0.160.0 and waits for its webhook.
# Jaeger, the Collector and the Starfleet workloads come from
# manifests/lab-start.yaml.
set -euo pipefail

CERT_MANAGER_VERSION="v1.21.2"
OTEL_OPERATOR_VERSION="v0.160.0"

echo "[playground] Installing cert-manager ${CERT_MANAGER_VERSION}..."
kubectl apply --server-side -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
for d in cert-manager cert-manager-cainjector cert-manager-webhook; do
  kubectl -n cert-manager rollout status "deployment/$d" --timeout=300s
done

echo "[playground] Installing the OpenTelemetry Operator ${OTEL_OPERATOR_VERSION}..."
# The cert-manager webhook can take a few seconds to accept requests after
# its pod is ready, so retry the apply.
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if kubectl apply --server-side -f "https://github.com/open-telemetry/opentelemetry-operator/releases/download/${OTEL_OPERATOR_VERSION}/opentelemetry-operator.yaml"; then
    break
  fi
  [ "$attempt" -eq 10 ] && { echo "[playground] ERROR: operator install failed" >&2; exit 1; }
  sleep 10
done
kubectl -n opentelemetry-operator-system rollout status deployment/opentelemetry-operator-controller-manager --timeout=300s
# The webhook Service needs endpoints before the Collector resource can be
# created, so wait for them.
for attempt in $(seq 1 30); do
  if kubectl -n opentelemetry-operator-system get endpointslices -l kubernetes.io/service-name=opentelemetry-operator-webhook-service -o jsonpath='{.items[*].endpoints[*].addresses[*]}' | grep -q .; then
    break
  fi
  sleep 5
done
echo "[playground] cert-manager and the OpenTelemetry Operator are ready."

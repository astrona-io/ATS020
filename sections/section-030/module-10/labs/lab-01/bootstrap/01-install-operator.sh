#!/usr/bin/env bash
# Tool install for the "Fix A Broken Collector Pipeline" lab
# (`ats-020-lab-030-01`).
#
# Installs the tools only; Jaeger, scout, shuttle and the broken Collector
# come from manifests/. This script:
#   1. installs cert-manager 1.21.2 (the OpenTelemetry Operator needs it for
#      its webhook certificate) and waits for it,
#   2. installs the OpenTelemetry Operator 0.160.0 and waits for it.
set -euo pipefail

CERT_MANAGER_VERSION="v1.21.2"
OTEL_OPERATOR_VERSION="v0.160.0"

echo "[lab] Installing cert-manager ${CERT_MANAGER_VERSION}..."
kubectl apply --server-side -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
for d in cert-manager cert-manager-cainjector cert-manager-webhook; do
  kubectl -n cert-manager rollout status "deployment/$d" --timeout=300s
done

echo "[lab] Installing the OpenTelemetry Operator ${OTEL_OPERATOR_VERSION}..."
# The cert-manager webhook can take a few seconds to accept requests after
# its pod is ready, so retry the apply.
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if kubectl apply --server-side -f "https://github.com/open-telemetry/opentelemetry-operator/releases/download/${OTEL_OPERATOR_VERSION}/opentelemetry-operator.yaml"; then
    break
  fi
  [ "$attempt" -eq 10 ] && { echo "[lab] ERROR: operator install failed" >&2; exit 1; }
  sleep 10
done
kubectl -n opentelemetry-operator-system rollout status deployment/opentelemetry-operator-controller-manager --timeout=300s

# The Operator's webhook must answer before a Collector can be created.
for attempt in $(seq 1 30); do
  if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: webhook-probe
  namespace: default
spec:
  config:
    receivers: {otlp: {protocols: {grpc: {}}}}
    exporters: {debug: {}}
    service: {pipelines: {traces: {receivers: [otlp], exporters: [debug]}}}
YAML
  then
    break
  fi
  [ "$attempt" -eq 30 ] && { echo "[lab] ERROR: operator webhook not ready" >&2; exit 1; }
  sleep 5
done
echo "[lab] cert-manager and the OpenTelemetry Operator are ready."

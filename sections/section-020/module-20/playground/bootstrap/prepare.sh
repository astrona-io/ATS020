#!/usr/bin/env bash
# OS prep for the "Collect Pod Logs With The OpenTelemetry Collector"
# playground (`ats-020-playground-020-02`).
#
# Environment preparation only; there is no task and no grading. This script:
#   1. installs cert-manager 1.21.3 (the OpenTelemetry Operator needs it for
#      its webhook certificate) and waits for it,
#   2. installs the OpenTelemetry Operator 0.162.0 and waits for its webhook,
#   3. puts Helm 4.3.2 on the PATH if it is missing and installs a trimmed
#      kube-prometheus-stack 92.22.0 (Prometheus Operator and one Prometheus)
#      into the `monitoring` namespace.
# No OpenTelemetryCollector is created: the reader writes it.
set -euo pipefail

CERT_MANAGER_VERSION="v1.21.3"
OTEL_OPERATOR_VERSION="v0.162.0"
HELM_VERSION="v4.3.2"
CHART_VERSION="92.22.0"

BIN_DIR="$HOME/.astrona/tools/ats020"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
export HELM_CACHE_HOME="$HOME/.astrona/helm/cache"
export HELM_CONFIG_HOME="$HOME/.astrona/helm/config"
export HELM_DATA_HOME="$HOME/.astrona/helm/data"

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
  [ "$attempt" -eq 30 ] && { echo "[playground] ERROR: operator webhook not ready" >&2; exit 1; }
  sleep 5
done

if ! command -v helm >/dev/null 2>&1 || ! helm version --short | grep -q "^v4.3.2"; then
  WORK="$(mktemp -d)"
  trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$WORK"' EXIT
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"; case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
  echo "[playground] Downloading Helm ${HELM_VERSION}..."
  curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz" | tar -xz -C "$WORK"
  install -m 0755 "$WORK/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
fi
helm version --short

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES=""
for candidate in "$SCRIPT_DIR/kps-values.yaml" "./bootstrap/kps-values.yaml" "./kps-values.yaml"; do
  [ -f "$candidate" ] && { VALUES="$candidate"; break; }
done
[ -n "$VALUES" ] || { echo "[playground] ERROR: kps-values.yaml not found" >&2; exit 1; }

echo "[playground] Installing kube-prometheus-stack ${CHART_VERSION} (trimmed)..."
helm upgrade --install kps kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version "$CHART_VERSION" \
  --namespace monitoring --create-namespace \
  -f "$VALUES" --wait --timeout 10m

kubectl -n monitoring rollout status statefulset/prometheus-kps-prometheus --timeout=300s
echo "[playground] cert-manager, the OpenTelemetry Operator and Prometheus are ready."

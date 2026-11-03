#!/usr/bin/env bash
# OS prep for the "Dashboards And Logs Capstone"
# lab (`ats-020-capstone-020`).
#
# Installs the tools only; the workloads come from manifests/. This script:
#   1. installs cert-manager 1.21.2 (the OpenTelemetry Operator needs it for
#      its webhook certificate) and waits for it,
#   2. installs the OpenTelemetry Operator 0.160.0 and waits for its webhook,
#   3. puts Helm 4.3.0 on the PATH if it is missing and installs a trimmed
#      kube-prometheus-stack 92.3.0 (Prometheus Operator, one Prometheus and Grafana)
#      into the `monitoring` namespace.
# No OpenTelemetryCollector is created: the learner writes it.
set -euo pipefail

CERT_MANAGER_VERSION="v1.21.2"
OTEL_OPERATOR_VERSION="v0.160.0"
HELM_VERSION="v4.3.0"
CHART_VERSION="92.3.0"

BIN_DIR="$HOME/.astrona/tools/ats020"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
export HELM_CACHE_HOME="$HOME/.astrona/helm/cache"
export HELM_CONFIG_HOME="$HOME/.astrona/helm/config"
export HELM_DATA_HOME="$HOME/.astrona/helm/data"

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

if ! command -v helm >/dev/null 2>&1 || ! helm version --short | grep -q "^v4.3.0"; then
  WORK="$(mktemp -d)"
  trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$WORK"' EXIT
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"; case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
  echo "[lab] Downloading Helm ${HELM_VERSION}..."
  curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz" | tar -xz -C "$WORK"
  install -m 0755 "$WORK/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
fi
helm version --short

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES=""
for candidate in "$SCRIPT_DIR/kps-values.yaml" "./bootstrap/kps-values.yaml" "./kps-values.yaml"; do
  [ -f "$candidate" ] && { VALUES="$candidate"; break; }
done
[ -n "$VALUES" ] || { echo "[lab] ERROR: kps-values.yaml not found" >&2; exit 1; }

echo "[lab] Installing kube-prometheus-stack ${CHART_VERSION} (trimmed, with Grafana)..."
helm upgrade --install kps kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version "$CHART_VERSION" \
  --namespace monitoring --create-namespace \
  -f "$VALUES" --wait --timeout 10m

kubectl -n monitoring rollout status statefulset/prometheus-kps-prometheus --timeout=300s
kubectl -n monitoring rollout status deployment/kps-grafana --timeout=300s
echo "[lab] cert-manager, the OpenTelemetry Operator, Prometheus and Grafana are ready."

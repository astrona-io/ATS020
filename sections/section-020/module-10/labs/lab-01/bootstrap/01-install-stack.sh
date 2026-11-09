#!/usr/bin/env bash
# Tool install for the "Fix A Grafana Dashboard That Is Provisioned From A
# ConfigMap" lab (`ats-020-lab-020-01`).
#
# Installs the stack only; the broken dashboard comes from manifests/. This script:
#   1. puts Helm 4.3.1 on the PATH if it is missing,
#   2. installs a trimmed kube-prometheus-stack 92.3.0 (Prometheus Operator and
#      one Prometheus and Grafana) into the `monitoring` namespace,
#   3. waits until Prometheus and Grafana are ready.
# The Starfleet workloads, their ServiceMonitors and the traffic loop come from
# manifests/lab-start.yaml.
set -euo pipefail

HELM_VERSION="v4.3.1"
CHART_VERSION="92.3.0"

BIN_DIR="$HOME/.astrona/tools/ats020"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
export HELM_CACHE_HOME="$HOME/.astrona/helm/cache"
export HELM_CONFIG_HOME="$HOME/.astrona/helm/config"
export HELM_DATA_HOME="$HOME/.astrona/helm/data"

if ! command -v helm >/dev/null 2>&1 || ! helm version --short | grep -q "^v4.3.1"; then
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

echo "[lab] Installing kube-prometheus-stack ${CHART_VERSION} (trimmed)..."
helm upgrade --install kps kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version "$CHART_VERSION" \
  --namespace monitoring --create-namespace \
  -f "$VALUES" --wait --timeout 10m

kubectl -n monitoring rollout status statefulset/prometheus-kps-prometheus --timeout=300s
kubectl -n monitoring rollout status deployment/kps-grafana --timeout=300s
echo "[lab] Prometheus and Grafana are ready."

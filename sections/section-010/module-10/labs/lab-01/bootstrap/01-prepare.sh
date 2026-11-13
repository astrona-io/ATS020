#!/usr/bin/env bash
# Environment setup for the lab "Get A Workload Scraped With A ServiceMonitor"
# (`ats-020-lab-010-01`). This script:
#   1. puts Helm 4.3.2 on the PATH if it is missing,
#   2. installs a trimmed kube-prometheus-stack 93.3.0 (Prometheus Operator and
#      one Prometheus) into the `monitoring` namespace,
#   3. waits until Prometheus is ready.
# The workloads come from manifests/lab-start.yaml and the faulty ServiceMonitor
# from manifests/servicemonitor-start.yaml (the fault is the material).
set -euo pipefail

HELM_VERSION="v4.3.2"
CHART_VERSION="93.3.0"

BIN_DIR="/usr/local/bin"
[ -w "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

if ! command -v helm >/dev/null 2>&1; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
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
echo "[lab] Prometheus is ready."

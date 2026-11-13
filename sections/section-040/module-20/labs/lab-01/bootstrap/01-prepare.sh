#!/usr/bin/env bash
# OS prep for the "Measure Service Levels And Resource Efficiency"
# lab "Fix The Burn-Rate Alert" (`ats-020-lab-040-02`).
#
# Environment preparation. The faulty rule comes later, from manifests/slo-rules-start.yaml. This script:
#   1. puts Helm 4.3.2 on the PATH if it is missing,
#   2. installs a trimmed kube-prometheus-stack 92.22.0 (Prometheus Operator,
#      one Prometheus, kube-state-metrics and the kubelet scrape job that
#      reads cAdvisor) into the `monitoring` namespace,
#   3. waits until Prometheus and kube-state-metrics are ready.
# metrics-server comes from the kind addon in config.yaml. The Starfleet
# workloads, their ServiceMonitor and the traffic loop come from
# manifests/lab-start.yaml.
set -euo pipefail

HELM_VERSION="v4.3.2"
CHART_VERSION="92.22.0"

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
kubectl -n monitoring rollout status deployment/kps-kube-state-metrics --timeout=300s
echo "[lab] Prometheus and kube-state-metrics are ready."

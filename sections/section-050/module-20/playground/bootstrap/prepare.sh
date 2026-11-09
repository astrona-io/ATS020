#!/usr/bin/env bash
# OS prep for the "Diagnose And Fix Broken Platform Components" playground
# (`ats-020-playground-050-02`).
#
# Environment preparation only. This script:
#   1. puts Helm 4.3.1 on the PATH if it is missing,
#   2. installs a trimmed kube-prometheus-stack 92.22.0 (Prometheus Operator and
#      one Prometheus) into the `monitoring` namespace and waits for Prometheus,
#   3. scales the Prometheus Operator to zero. This is one of the three faults
#      and it is never fixed here.
# The workloads, the webhooks and their faults come from manifests/lab-start.yaml.
set -euo pipefail

HELM_VERSION="v4.3.1"
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

for attempt in $(seq 1 60); do
  kubectl -n monitoring get statefulset/prometheus-kps-prometheus >/dev/null 2>&1 && break
  sleep 5
done
kubectl -n monitoring rollout status statefulset/prometheus-kps-prometheus --timeout=300s

echo "[playground] Scaling the Prometheus Operator to zero (fault 3)."
kubectl -n monitoring scale deployment/kps-operator --replicas=0
kubectl -n monitoring wait --for=delete pod -l app=kube-prometheus-stack-operator --timeout=120s || true
echo "[playground] Done."

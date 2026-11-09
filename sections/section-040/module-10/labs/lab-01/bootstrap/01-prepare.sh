#!/usr/bin/env bash
# Environment setup for the lab "Fix The Change Failure Rate Rule"
# (`ats-020-lab-040-01`).
#
# This script prepares the delivery history. The faulty rule comes later, from
# manifests/dora-rules-start.yaml. This script:
#   1. puts Helm 4.3.0 on the PATH if it is missing,
#   2. installs a trimmed kube-prometheus-stack 92.3.0 (Prometheus Operator
#      and one Prometheus) into `monitoring`,
#   3. installs Gitea 28.1.0 (plumbing: the Git server) into `gitea`,
#   4. installs Argo CD 3.6.1 into `argocd` and scales down the parts that
#      this module does not use,
#   5. tells Prometheus to scrape the Argo CD application controller,
#   6. creates the project `default`, the repository `starfleet-deploy` and the Application `scout`,
#   7. runs seed-history.sh, which makes ten commits and waits for Argo CD to
#      sync each one. Two commits are bad on purpose (an image tag that does
#      not exist).
# Prometheus scrapes Argo CD while the seed runs, so the metrics hold the
# whole history.
set -euo pipefail

HELM_VERSION="v4.3.0"
CHART_VERSION="92.3.0"
ARGOCD_VERSION="v3.6.1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
find_file() {
  for candidate in "$SCRIPT_DIR/$1" "./bootstrap/$1" "./$1"; do
    [ -f "$candidate" ] && { echo "$candidate"; return 0; }
  done
  echo "[playground] ERROR: $1 not found" >&2
  return 1
}

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

echo "[playground] Installing kube-prometheus-stack ${CHART_VERSION} (trimmed)..."
helm upgrade --install kps kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version "$CHART_VERSION" \
  --namespace monitoring --create-namespace \
  -f "$(find_file kps-values.yaml)" --wait --timeout 10m
kubectl -n monitoring rollout status statefulset/prometheus-kps-prometheus --timeout=300s

echo "[playground] Installing Gitea 28.1.0 (plumbing)..."
kubectl apply -f "$(find_file gitea.yaml)"
kubectl -n gitea rollout status deployment/gitea --timeout=300s

echo "[playground] Installing Argo CD ${ARGOCD_VERSION}..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
# Save memory: this module uses only the application controller, the
# repository server and Redis.
kubectl -n argocd scale deployment argocd-server argocd-dex-server argocd-notifications-controller argocd-applicationset-controller --replicas=0
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deployment/argocd-redis --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

# The server normally creates the `default` project; create it here, before
# the Application, so the controller finds it.
kubectl apply -f "$(find_file appproject.yaml)"
kubectl apply -f "$(find_file argocd-monitor.yaml)"

echo "[playground] Creating the repository starfleet-deploy..."
bash "$(find_file seed-history.sh)" init

kubectl apply -f "$(find_file application.yaml)"
echo "[playground] Making the delivery history (ten commits, two of them bad)..."
bash "$(find_file seed-history.sh)" history
echo "[playground] Argo CD, Gitea and Prometheus are ready."

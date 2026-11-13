#!/usr/bin/env bash
# Prepares `ats-020-capstone-020-02`: removes old answer files, installs Helm if
# it is missing, installs the trimmed monitoring stack and saves the starting
# dashboard. Loki, the Collector, the workloads and the Prometheus data source
# come from manifests/lab-start.yaml.
set -euo pipefail

rm -f /tmp/ats-020-incident-service.txt /tmp/ats-020-incident-path.txt

HELM_VERSION="v4.3.2"
CHART_VERSION="92.22.0"

BIN_DIR="$HOME/.astrona/tools/ats020"
mkdir -p "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"
export HELM_CACHE_HOME="$HOME/.astrona/helm/cache"
export HELM_CONFIG_HOME="$HOME/.astrona/helm/config"
export HELM_DATA_HOME="$HOME/.astrona/helm/data"

for tool in kubectl curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "[setup] ERROR: $tool is required" >&2; exit 1; }
done

# Install Helm only if it is missing. Never replace a Helm the terminal already has.
if ! command -v helm >/dev/null 2>&1; then
  WORK="$(mktemp -d)"
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"; case "$ARCH" in x86_64) ARCH=amd64 ;; aarch64|arm64) ARCH=arm64 ;; esac
  echo "[setup] Downloading Helm ${HELM_VERSION}..."
  curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz" | tar -xz -C "$WORK"
  install -m 0755 "$WORK/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
  rm -rf "$WORK"
fi
helm version --short

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES=""
for candidate in "$SCRIPT_DIR/kps-values.yaml" "./bootstrap/kps-values.yaml" "./kps-values.yaml"; do
  [ -f "$candidate" ] && { VALUES="$candidate"; break; }
done
[ -n "$VALUES" ] || { echo "[setup] ERROR: kps-values.yaml not found" >&2; exit 1; }

echo "[setup] Installing kube-prometheus-stack ${CHART_VERSION}..."
helm upgrade --install kps kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --version "$CHART_VERSION" \
  --namespace monitoring --create-namespace \
  -f "$VALUES" --wait --timeout 10m
kubectl -n monitoring rollout status statefulset/prometheus-kps-prometheus --timeout=300s
kubectl -n monitoring rollout status deployment/kps-grafana --timeout=300s

GRAFANA_PORT=$((13800 + RANDOM % 500))
GRAFANA="http://127.0.0.1:${GRAFANA_PORT}"
kubectl -n monitoring port-forward svc/kps-grafana "${GRAFANA_PORT}:80" >/dev/null 2>&1 &
FORWARD_PID=$!
trap 'kill "$FORWARD_PID" 2>/dev/null' EXIT
for _ in $(seq 1 30); do
  curl -fsS "$GRAFANA/api/health" >/dev/null 2>&1 && break
  sleep 2
done
grafana() { curl -fsS -u admin:starfleet -H 'Content-Type: application/json' "$@"; }

# Saved in Grafana's database, not provisioned, so it can be edited. Both panels
# start with queries that hide the incident, and the Loki panel names a data
# source that does not exist yet.
jq -n '
  def prometheus: {type: "prometheus", uid: "prometheus"};
  def loki: {type: "loki", uid: "loki"};
  {
    dashboard: {
      uid: "incident-overview",
      title: "Incident Overview",
      schemaVersion: 42,
      time: {from: "now-1h", to: "now"},
      panels: [
        {
          id: 1, title: "Failed requests", type: "timeseries", datasource: prometheus,
          gridPos: {h: 10, w: 24, x: 0, y: 0},
          targets: [{refId: "A", datasource: prometheus, expr: "sum by (service) (rate(fleet_requests_total{namespace=\"outpost\",status=\"200\"}[5m]))"}]
        },
        {
          id: 2, title: "Error lines", type: "logs", datasource: loki,
          gridPos: {h: 12, w: 24, x: 0, y: 10},
          targets: [{refId: "A", datasource: loki, queryType: "range", expr: "{namespace=\"starfleet\"}"}]
        }
      ]
    },
    overwrite: true,
    message: "Starting dashboard"
  }' | grafana -X POST "$GRAFANA/api/dashboards/db" -d @- >/dev/null
echo "[setup] Prometheus and Grafana are ready."

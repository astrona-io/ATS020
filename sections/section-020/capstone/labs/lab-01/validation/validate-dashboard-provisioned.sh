#!/usr/bin/env bash
# Grades the loading path: a ConfigMap with the dashboard sidecar's label must
# hold the dashboard, and Grafana must report it as provisioned. A dashboard
# made by hand in the Grafana database is not provisioned and would be lost when
# the pod is replaced. The sidecar needs a few seconds, so retry.
set -u
fail() { echo "FAIL: $*"; exit 1; }

# Grafana has no auth through the API server proxy, so use a port-forward.
GRAFANA_PORT=$((13300 + RANDOM % 500))
GRAFANA="http://127.0.0.1:${GRAFANA_PORT}"
kubectl -n monitoring port-forward svc/kps-grafana "${GRAFANA_PORT}:80" >/dev/null 2>&1 &
FORWARD_PID=$!
trap 'kill "$FORWARD_PID" 2>/dev/null' EXIT
for _ in $(seq 1 30); do
  curl -fsS "$GRAFANA/api/health" >/dev/null 2>&1 && break
  sleep 2
done
grafana_get() { curl -fsS -u admin:starfleet "$GRAFANA$1" 2>/dev/null; }

holder=$(kubectl get configmap -A -l grafana_dashboard=1 -o json |
  jq -r '[.items[] | select([.data[]? | try (fromjson | .uid) catch empty] | index("outpost-overview")) | .metadata.name] | join(",")')
[[ -n "$holder" ]] || fail "no ConfigMap with the label grafana_dashboard=1 holds the dashboard outpost-overview; the sidecar only reads labelled ConfigMaps"

provisioned=""
for _ in $(seq 1 36); do
  provisioned=$(grafana_get /api/dashboards/uid/outpost-overview | jq -r '.meta.provisioned // empty')
  [[ "$provisioned" == "true" ]] && break
  sleep 5
done
[[ "$provisioned" == "true" ]] || fail "Grafana does not report the dashboard outpost-overview as provisioned; a dashboard created through the API or the web interface does not survive a pod replacement"
echo "PASS: the dashboard outpost-overview is provisioned from the ConfigMap $holder"

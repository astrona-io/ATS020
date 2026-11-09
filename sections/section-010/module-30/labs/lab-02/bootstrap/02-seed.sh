#!/usr/bin/env bash
# Seed the independent starting state and wait for the maintenance alert.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
kubectl apply -f "$LAB_DIR/manifests/lab-start.yaml"
kubectl apply -f "$LAB_DIR/manifests/maintenance.yaml"
kubectl apply -f "$LAB_DIR/manifests/route-start.yaml"
kubectl apply -f "$LAB_DIR/manifests/team-rule.yaml"
kubectl -n monitoring rollout status deploy/alert-receiver --timeout=180s
for attempt in $(seq 1 60); do
  if kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts' | jq -e 'any(.[]; .labels.alertname == "ProbeMaintenance" and .labels.namespace == "starfleet")' >/dev/null; then
    exit 0
  fi
  sleep 5
done
echo 'Maintenance alert has not reached Alertmanager' >&2
exit 1

#!/usr/bin/env bash
set -euo pipefail
kubectl -n telemetry create secret generic grafana-admin \
  --from-literal=admin-password=starfleet \
  --from-literal=password=starfleet \
  --dry-run=client -o yaml | kubectl apply -f -


kubectl -n telemetry rollout status deployment/grafana --timeout=180s

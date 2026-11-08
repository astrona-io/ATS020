#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$SCRIPT_DIR/solution.yaml"
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- \
  amtool silence add alertname=ProbeMaintenance namespace=starfleet \
  --duration=30m --author=platform --comment='probe maintenance window' \
  --alertmanager.url=http://localhost:9093

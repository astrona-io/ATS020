#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- \
  amtool silence add alertname=ProbeMaintenance namespace=starfleet \
  --duration=30m --author=platform --comment='probe maintenance window' \
  --alertmanager.url=http://localhost:9093

#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring label configmap dashboard-scout-overview grafana_dashboard=1 --overwrite

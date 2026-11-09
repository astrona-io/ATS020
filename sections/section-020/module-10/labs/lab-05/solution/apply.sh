#!/usr/bin/env bash
set -euo pipefail
kubectl -n telemetry set resources deployment/grafana \
  --requests=memory=128Mi --limits=memory=512Mi


kubectl -n telemetry rollout status deployment/grafana --timeout=180s

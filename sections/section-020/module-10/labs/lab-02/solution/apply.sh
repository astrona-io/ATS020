#!/usr/bin/env bash
set -euo pipefail
kubectl -n telemetry patch deployment grafana --type=strategic -p '{
  "spec": {"template": {"spec": {"volumes": [
    {"name": "grafana-storage", "configMap": null, "emptyDir": {}}
  ]}}}
}'


kubectl -n telemetry rollout status deployment/grafana --timeout=180s

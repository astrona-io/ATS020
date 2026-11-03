#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Creates the Collector with its permission and ServiceMonitor, and replaces
# the dashboard ConfigMap with a labelled one whose third panel uses the right
# label. Keep in step with solution.md.
set -euo pipefail
cd "$(dirname "$0")"
kubectl apply -f solution.yaml
kubectl -n monitoring rollout status daemonset/logs-collector --timeout=180s

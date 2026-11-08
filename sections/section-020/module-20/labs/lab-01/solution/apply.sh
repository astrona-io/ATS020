#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Binds the ClusterRole to the Collector's service account and labels the
# ServiceMonitor. Keep in step with solution.md.
set -euo pipefail
cd "$(dirname "$0")"
kubectl apply -f solution.yaml

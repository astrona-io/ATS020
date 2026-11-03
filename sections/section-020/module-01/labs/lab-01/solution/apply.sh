#!/usr/bin/env bash
# Reference solution, applied only by `astrona test`.
# Replaces the dashboard ConfigMap with a labelled one whose panels use the data
# source UID `prometheus`. Keep in step with solution.md.
set -euo pipefail
cd "$(dirname "$0")"
kubectl apply -f solution.yaml

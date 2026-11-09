#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring scale deployment/kps-operator --replicas=1
kubectl -n monitoring rollout status deployment/kps-operator --timeout=180s

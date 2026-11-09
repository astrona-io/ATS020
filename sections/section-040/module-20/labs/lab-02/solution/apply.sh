#!/usr/bin/env bash
set -euo pipefail
kubectl -n starfleet set resources deployment/scout --requests=cpu=10m,memory=64Mi --limits=memory=128Mi
kubectl -n starfleet rollout status deployment/scout --timeout=180s

#!/usr/bin/env bash
set -euo pipefail
kubectl -n starfleet set resources deployment/probe --requests=cpu=5m,memory=24Mi
kubectl -n starfleet rollout status deployment/probe --timeout=180s

#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "$script_dir/solution.yaml"
kubectl -n starfleet rollout status deployment/scout --timeout=180s

#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
solution_file=""
for candidate in "$script_dir/solution.yaml" ./solution/solution.yaml ./solution.yaml; do
  if [ -f "$candidate" ]; then solution_file="$candidate"; break; fi
done
[ -n "$solution_file" ] || { echo 'Cannot find solution.yaml' >&2; exit 1; }
kubectl apply -f "$solution_file"
# A new Pod sees the updated ConfigMap immediately. No mount propagation wait
# or lifecycle endpoint is needed when using this restart route.
kubectl -n monitoring rollout restart deploy/prometheus-raw
kubectl -n monitoring rollout status deploy/prometheus-raw --timeout=180s

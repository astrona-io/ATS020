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
for attempt in $(seq 1 36); do
  result="$(kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/query?query=sum%20by%20%28deployment%29%20%28starfleet_queue_items%7Bjob%3D%22starfleet-pods%22%2Cnamespace%3D%22starfleet%22%7D%29' 2>/dev/null || true)"
  if jq -e '.status == "success" and (.data.result | length) == 2' <<<"$result" >/dev/null 2>&1; then
    winner="$(jq -r '.data.result | max_by(.value[1] | tonumber) | .metric.deployment' <<<"$result")"
    case "$winner" in scout|probe) ;; *) echo 'Unexpected winner' >&2; exit 1 ;; esac
    kubectl -n starfleet scale deployment "$winner" --replicas=3
    kubectl -n starfleet rollout status deployment/"$winner" --timeout=180s
    exit 0
  fi
  sleep 5
done
echo 'Both workload metrics did not arrive' >&2
exit 1

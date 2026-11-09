#!/usr/bin/env bash
set -euo pipefail
LOKI_API="/api/v1/namespaces/logging/services/loki:3100/proxy/loki/api/v1"
uri() { jq -rn --arg value "$1" '$value | @uri'; }
# Wait until Loki holds ERROR lines from every Pod that writes them, including
# probe, which logs ERROR only for the failing requests from shuttle.
query='sum by (pod) (count_over_time({namespace="outpost"} |= "ERROR" [6h]))'
ready=""
for _ in $(seq 1 60); do
  pods=$(kubectl get --raw "$LOKI_API/query?query=$(uri "$query")" 2>/dev/null | jq -r '.data.result[].metric.pod' || true)
  probes=$(grep -c '^probe-' <<< "$pods" || true)
  cargos=$(grep -c '^cargo-' <<< "$pods" || true)
  if [ "$probes" -ge 2 ] && [ "$cargos" -ge 2 ]; then
    ready=yes
    break
  fi
  sleep 5
done
[ -n "$ready" ] || { echo "Loki did not receive the ERROR lines in time" >&2; exit 1; }

kubectl -n outpost scale deployment/probe --replicas=0
kubectl -n outpost scale statefulset/cargo --replicas=0
kubectl -n outpost wait --for=delete pod -l app=probe --timeout=120s
kubectl -n outpost wait --for=delete pod -l app=cargo --timeout=120s

#!/usr/bin/env bash
# Waits until metrics-server serves the resource metrics API, so that
# `kubectl top` works in the playground. It changes no workload: the faults in
# manifests/lab-start.yaml are the material and are never fixed here.
set -euo pipefail

echo "[prepare] waiting for metrics-server"
kubectl -n kube-system rollout status deployment/metrics-server --timeout=240s
for attempt in $(seq 1 60); do
  if kubectl top nodes >/dev/null 2>&1; then
    echo "[prepare] metrics-server answers"
    exit 0
  fi
  sleep 5
done
echo "[prepare] metrics-server did not answer in time" >&2
exit 1

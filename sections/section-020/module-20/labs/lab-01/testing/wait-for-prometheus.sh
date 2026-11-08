#!/usr/bin/env bash
# Helper for `astrona test`: waits until Prometheus answers queries through the
# API server proxy, so the validation scripts do not start too early.
set -u
for _ in $(seq 1 60); do
  if kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/-/ready' >/dev/null 2>&1; then
    echo "Prometheus is ready"
    exit 0
  fi
  sleep 5
done
echo "Prometheus did not become ready" >&2
exit 1

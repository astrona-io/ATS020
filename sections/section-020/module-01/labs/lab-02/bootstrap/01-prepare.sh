#!/usr/bin/env bash
# Prepares `ats-020-lab-020-01-02`: checks the tools the lab needs and prints
# the state of the Grafana Pod. The Deployment is broken on purpose, so this
# script does not wait for it to become ready. The starting state comes from
# manifests/lab-start.yaml.
set -euo pipefail

for tool in kubectl curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "[setup] ERROR: $tool is required" >&2; exit 1; }
done

# Give the Deployment controller a moment to create the Pod, so the learner
# sees it on the first `kubectl get pods`.
for _ in $(seq 1 30); do
  pods=$(kubectl -n telemetry get pods -l app=grafana --no-headers 2>/dev/null || true)
  [ -n "$pods" ] && break
  sleep 2
done

echo "[setup] Grafana was moved to the namespace telemetry and does not start:"
kubectl -n telemetry get deployment,pods -l app=grafana || true
echo "[setup] Lab ats-020-lab-020-01-02 ready."

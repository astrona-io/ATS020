#!/usr/bin/env bash
# Reference solution for ats-020-lab-020-01-02. Applied only by `astrona test`.
# Fixes the three faults with the changes the task allows: a volume, a Secret
# and a resource limit. It does not touch the image, the environment names,
# the probes or the Service.
set -euo pipefail

# 1. The data directory must be writable. A ConfigMap volume is read-only and
#    the ConfigMap does not exist, so replace the volume with an emptyDir. The
#    strategic merge patch finds the volume by name; the null removes configMap.
kubectl -n telemetry patch deployment grafana --type=strategic -p '{
  "spec": {"template": {"spec": {"volumes": [
    {"name": "grafana-storage", "configMap": null, "emptyDir": {}}
  ]}}}
}'

# 2. The container reads the admin password from the key admin-password.
#    Recreate the Secret with that key; keep the old key so nothing else breaks.
kubectl -n telemetry create secret generic grafana-admin \
  --from-literal=admin-password=starfleet \
  --from-literal=password=starfleet \
  --dry-run=client -o yaml | kubectl apply -f -

# 3. Grafana needs far more than 32Mi of memory to start.
kubectl -n telemetry set resources deployment/grafana \
  --requests=memory=128Mi --limits=memory=512Mi

kubectl -n telemetry rollout status deployment/grafana --timeout=180s

# Wait until Grafana answers its health endpoint through the API server proxy.
HEALTH="/api/v1/namespaces/telemetry/services/grafana:3000/proxy/api/health"
for _ in $(seq 1 60); do
  if kubectl get --raw "$HEALTH" 2>/dev/null | jq -e '.database == "ok"' >/dev/null 2>&1; then
    echo "Grafana is up in telemetry."
    exit 0
  fi
  sleep 2
done
echo "Grafana did not report a healthy database in time" >&2
exit 1

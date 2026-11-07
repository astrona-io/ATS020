#!/usr/bin/env bash
# Grader: the task allows changes to resource requests and limits, Secrets,
# volumes and volumeMounts only. This script checks that the image, the
# environment variable names, the probes, the command and the Service are as
# they were, that the data directory /var/lib/grafana is still mounted and is
# not a ConfigMap any more, that the data source mount is still there, and
# that the memory limit is at least 256Mi.
set -uo pipefail
fail() { echo "FAIL: only-allowed-changes: $*"; exit 1; }

# to_mebibytes <quantity>: 512Mi -> 512, 1Gi -> 1024, 268435456 -> 256
to_mebibytes() {
  case "$1" in
    *Ki) awk -v value="${1%Ki}" 'BEGIN { printf "%d", value / 1024 }' ;;
    *Mi) echo "${1%Mi}" ;;
    *Gi) awk -v value="${1%Gi}" 'BEGIN { printf "%d", value * 1024 }' ;;
    *M) awk -v value="${1%M}" 'BEGIN { printf "%d", value * 1000000 / 1048576 }' ;;
    *G) awk -v value="${1%G}" 'BEGIN { printf "%d", value * 1000000000 / 1048576 }' ;;
    '') echo 0 ;;
    *) awk -v value="$1" 'BEGIN { printf "%d", value / 1048576 }' ;;
  esac
}

deploy=$(kubectl -n telemetry get deployment grafana -o json 2>/dev/null) ||
  fail "the Deployment grafana does not exist in the namespace telemetry"
container='.spec.template.spec.containers[] | select(.name == "grafana")'

echo "$deploy" | jq -e "[$container] | length == 1" >/dev/null ||
  fail "the Deployment must keep exactly one container named grafana"
image=$(echo "$deploy" | jq -r "$container | .image")
[ "$image" = "docker.io/grafana/grafana:13.2.3-distroless" ] ||
  fail "the image changed to ${image}. Keep docker.io/grafana/grafana:13.2.3-distroless"
echo "$deploy" | jq -e "$container | (.command // []) == [] and (.args // []) == []" >/dev/null ||
  fail "the container command or args changed. Leave them as they were"

for name in GF_SECURITY_ADMIN_USER GF_SECURITY_ADMIN_PASSWORD GF_PATHS_PROVISIONING; do
  echo "$deploy" | jq -e --arg name "$name" "$container | any(.env[]?; .name == \$name)" >/dev/null ||
    fail "the environment variable ${name} is gone. Keep every environment variable name"
done
echo "$deploy" | jq -e "$container | any(.env[]?; .name == \"GF_SECURITY_ADMIN_PASSWORD\" and .valueFrom.secretKeyRef.name == \"grafana-admin\")" >/dev/null ||
  fail "GF_SECURITY_ADMIN_PASSWORD must still come from the Secret grafana-admin. Change the Secret, not the environment variable"
echo "$deploy" | jq -e "$container | (.readinessProbe.httpGet.path == \"/api/health\") and (.livenessProbe.httpGet.path == \"/api/health\")" >/dev/null ||
  fail "the readiness or liveness probe changed. Leave the probes as they were"

storage_volume=$(echo "$deploy" | jq -r "$container | .volumeMounts[]? | select(.mountPath == \"/var/lib/grafana\") | .name" | head -1)
[ -n "$storage_volume" ] || fail "nothing is mounted at /var/lib/grafana any more. Grafana must keep its data directory"
echo "$deploy" | jq -e --arg name "$storage_volume" '.spec.template.spec.volumes[] | select(.name == $name) | has("configMap") | not' >/dev/null ||
  fail "the volume behind /var/lib/grafana is still a ConfigMap. A ConfigMap is read-only; use a volume Grafana can write to, for example an emptyDir"
echo "$deploy" | jq -e "$container | any(.volumeMounts[]?; .mountPath == \"/etc/grafana/provisioning/datasources\")" >/dev/null ||
  fail "the data source provisioning mount at /etc/grafana/provisioning/datasources is gone. Keep it"
datasource_volume=$(echo "$deploy" | jq -r "$container | .volumeMounts[]? | select(.mountPath == \"/etc/grafana/provisioning/datasources\") | .name" | head -1)
echo "$deploy" | jq -e --arg name "$datasource_volume" '.spec.template.spec.volumes[] | select(.name == $name) | .configMap.name == "grafana-datasources"' >/dev/null ||
  fail "the data source mount must still come from the ConfigMap grafana-datasources"

limit=$(echo "$deploy" | jq -r "$container | .resources.limits.memory // \"\"")
[ -n "$limit" ] || fail "the container has no memory limit. Set one of at least 256Mi"
[ "$(to_mebibytes "$limit")" -ge 256 ] ||
  fail "the memory limit is ${limit}. Grafana needs at least 256Mi to start"

svc=$(kubectl -n telemetry get service grafana -o json 2>/dev/null) ||
  fail "the Service grafana does not exist in the namespace telemetry"
echo "$svc" | jq -e '.spec.selector.app == "grafana" and any(.spec.ports[]; .port == 3000)' >/dev/null ||
  fail "the Service grafana changed. Keep its selector app=grafana and port 3000"

echo "PASS: only-allowed-changes: only limits, the Secret and the volume changed"

#!/usr/bin/env bash
# Grader: the Secret grafana-admin in telemetry holds the key admin-password
# the container reads, and the user admin signs in with the password
# starfleet. /api/org needs a login, so the grader forwards the Service to a
# local port and asks it with HTTP basic authentication.
set -uo pipefail
fail() { echo "FAIL: login-works: $*"; exit 1; }

# The design must stay (checked first): only the Secret may change. The
# image, command, environment variable names and Secret reference, probes,
# volumes, memory limit and Service stay as they were.
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


kubectl -n telemetry get secret grafana-admin >/dev/null 2>&1 ||
  fail "the Secret grafana-admin does not exist in the namespace telemetry"
password=$(kubectl -n telemetry get secret grafana-admin -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null)
[ -n "$password" ] || fail "the Secret grafana-admin in telemetry has no key admin-password. The container reads its password from that key"
[ "$password" = "starfleet" ] || fail "the key admin-password of the Secret grafana-admin must hold the password starfleet"

kubectl -n telemetry rollout status deployment/grafana --timeout=120s >/dev/null 2>&1 ||
  fail "the Deployment grafana is not ready, so nobody can sign in"

GRAFANA_PORT=$((13300 + RANDOM % 500))
GRAFANA="http://127.0.0.1:${GRAFANA_PORT}"
kubectl -n telemetry port-forward svc/grafana "${GRAFANA_PORT}:3000" >/dev/null 2>&1 &
FORWARD_PID=$!
trap 'kill "$FORWARD_PID" 2>/dev/null' EXIT
up=""
for _ in $(seq 1 30); do
  curl -fsS "$GRAFANA/api/health" >/dev/null 2>&1 && { up=yes; break; }
  sleep 2
done
[ -n "$up" ] || fail "the Service grafana in telemetry does not answer on port 3000"

status=$(curl -s -o /dev/null -w '%{http_code}' -u admin:starfleet "$GRAFANA/api/org" 2>/dev/null || echo 000)
[ "$status" = "200" ] ||
  fail "signing in as admin with the password starfleet gives HTTP ${status}, expected 200. The running Pod must read the new Secret value, so restart the rollout after you change the Secret"
echo "PASS: login-works: admin signs in with the password starfleet"

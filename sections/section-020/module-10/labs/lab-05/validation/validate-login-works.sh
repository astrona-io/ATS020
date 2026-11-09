#!/usr/bin/env bash
# Grader: the Secret grafana-admin in telemetry holds the key admin-password
# the container reads, and the user admin signs in with the password
# starfleet. /api/org needs a login, so the grader forwards the Service to a
# local port and asks it with HTTP basic authentication.
set -uo pipefail
fail() { echo "FAIL: login-works: $*"; exit 1; }

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

#!/usr/bin/env bash
# Applies the reference solution. Run by `astrona test` only.
#   1. fixes the targetPort of the Service starfleet-policy,
#   2. signs a new serving certificate for outpost-policy with the CA in the
#      Secret webhook-ca, stores it and restarts the webhook server,
#   3. scales the Prometheus Operator back to one replica.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE=""
for candidate in "$SCRIPT_DIR/solution.yaml" "./solution/solution.yaml" "./solution.yaml"; do
  [ -f "$candidate" ] && { FILE="$candidate"; break; }
done
[ -n "$FILE" ] || { echo "[solution] ERROR: solution.yaml not found" >&2; exit 1; }
kubectl apply -f "$FILE"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
kubectl -n webhook-system get secret webhook-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > "$WORK/ca.crt"
kubectl -n webhook-system get secret webhook-ca -o jsonpath='{.data.tls\.key}' | base64 -d > "$WORK/ca.key"
openssl req -newkey rsa:2048 -nodes -keyout "$WORK/tls.key" -out "$WORK/tls.csr" \
  -subj "/CN=outpost-policy.webhook-system.svc" >/dev/null 2>&1
printf 'subjectAltName=DNS:outpost-policy.webhook-system.svc\nextendedKeyUsage=serverAuth\n' > "$WORK/san.ext"
openssl x509 -req -in "$WORK/tls.csr" -CA "$WORK/ca.crt" -CAkey "$WORK/ca.key" -CAcreateserial \
  -days 365 -extfile "$WORK/san.ext" -out "$WORK/tls.crt" >/dev/null 2>&1
kubectl -n webhook-system create secret tls outpost-policy-tls --cert="$WORK/tls.crt" --key="$WORK/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n webhook-system rollout restart deployment/outpost-policy
kubectl -n webhook-system rollout status deployment/outpost-policy --timeout=180s

kubectl -n monitoring scale deployment/kps-operator --replicas=1
kubectl -n monitoring rollout status deployment/kps-operator --timeout=180s
echo "[solution] the three faults are fixed."

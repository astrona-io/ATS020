#!/usr/bin/env bash
set -euo pipefail
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

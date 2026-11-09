# Solution: Renew An Expired Webhook Certificate

## Inspect the starting state

Use the API error to locate the failing component.

```sh
kubectl -n outpost create deployment lab-check --image=ghcr.io/stefanprodan/podinfo:6.17.0
```

```sh
kubectl -n webhook-system get secret outpost-policy-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates -subject
```

## Make the repair

Sign a replacement with the existing certificate authority (CA), then reload the server. The service name must appear in the subject alternative name.

```sh
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
```

## Verify the result

A successful create and a new server log entry prove admission works:

```sh
kubectl -n outpost create deployment lab-check --image=ghcr.io/stefanprodan/podinfo:6.17.0
kubectl -n webhook-system logs deploy/outpost-policy --tail=10
kubectl -n outpost delete deployment lab-check
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-050/module-20/labs/lab-02
```

# An Expired Webhook Certificate

A webhook can have a Service with endpoints and a healthy pod and still fail. The API server talks to a webhook over HTTPS, so it checks the certificate that the webhook shows. If that certificate is expired or not trusted, the API server refuses the connection. This part reads the `x509` error, inspects the certificate with `openssl`, signs a new one with the certificate authority (CA) of the platform, and proves the fix. It uses the webhook `outpost-policy`.

The commands need the playground as it starts: the namespace `outpost`, the webhook server `outpost-policy` in `webhook-system` with its Secret `outpost-policy-tls`, and the Secret `webhook-ca`. They also need `openssl` on your machine.

## Who trusts which certificate

A serving certificate is the certificate a server shows to prove its name during the TLS handshake. A certificate authority (CA) signs it. A client trusts the certificate only if the CA that signed it is in the client's list of trusted CAs, and only while the certificate is inside its validity dates. For a webhook, the client is the API server. The trusted CA comes from the field `caBundle` in the `ValidatingWebhookConfiguration`.

The webhook server reads its certificate and private key from the Secret `outpost-policy-tls`. The server loads them once, when it starts. This detail matters later: a new Secret alone does not change a running server.

## Read the error

Create a Deployment in `outpost`. The Service of this webhook is healthy, so the error is different from the previous failure:

<!-- astrona:playground:renew -->

```sh
kubectl -n outpost create deployment probe --image=mccutchen/go-httpbin:2.25.0
```

```text
error: failed to create deployment: Internal error occurred: failed calling webhook "outpost-policy.astrona.io": failed to call webhook: Post "https://outpost-policy.webhook-system.svc:443/validate?timeout=5s": tls: failed to verify certificate: x509: certificate has expired or is not yet valid: current time 2026-11-02T20:57:14Z is after 2025-01-08T00:00:00Z
```

The start is the same: the API server could not call the webhook. The end is new. The connection worked, because there was a TLS handshake. Then `tls: failed to verify certificate` and `x509: certificate has expired` say that the API server rejected the certificate. The message even gives the date: the certificate ended at `2025-01-08T00:00:00Z`, and the current time is later.

## Inspect the certificate

Confirm the date with `openssl`. Read the certificate from the Secret, and read the CA that the webhook configuration trusts:

```sh
kubectl -n webhook-system get secret outpost-policy-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer -startdate -enddate
kubectl get validatingwebhookconfiguration outpost-policy -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d | openssl x509 -noout -subject -enddate
```

```text
subject=CN=outpost-policy.webhook-system.svc
issuer=CN=starfleet-webhook-ca
notBefore=Jan  1 00:00:00 2025 GMT
notAfter=Jan  8 00:00:00 2025 GMT
subject=CN=starfleet-webhook-ca
notAfter=Oct  9 20:47:39 2126 GMT
```

The serving certificate is for the name `outpost-policy.webhook-system.svc`, and `notAfter` is in January 2025. The issuer is `starfleet-webhook-ca`, which is the subject of the CA in the `caBundle`. The CA is valid until 2126. So the trust is right, and only the serving certificate is old. The fix is a new serving certificate signed by the same CA, because then `caBundle` stays correct.

## Sign a new certificate

The platform keeps its CA in the Secret `webhook-ca`. Work in an empty directory. Copy the CA certificate and key out of the Secret, then create a new private key and a certificate signing request (CSR) for the same name:

```sh
mkdir certs && cd certs
kubectl -n webhook-system get secret webhook-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > ca.crt
kubectl -n webhook-system get secret webhook-ca -o jsonpath='{.data.tls\.key}' | base64 -d > ca.key
openssl req -newkey rsa:2048 -nodes -keyout tls.key -out tls.csr -subj "/CN=outpost-policy.webhook-system.svc"
```

The `openssl req` command prints progress dots and a line of dashes, which are left out here. It writes `tls.key` and `tls.csr`. The API server checks the name of the Service against the subject alternative name (SAN) of the certificate, so the new certificate must list that name. Save this as `san.ext`:

```text
subjectAltName=DNS:outpost-policy.webhook-system.svc
extendedKeyUsage=serverAuth
```

Sign the request with the CA for 365 days, and check the result:

```sh
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -extfile san.ext -out tls.crt
openssl x509 -in tls.crt -noout -subject -issuer -enddate
```

```text
Certificate request self-signature ok
subject=CN=outpost-policy.webhook-system.svc
subject=CN=outpost-policy.webhook-system.svc
issuer=CN=starfleet-webhook-ca
notAfter=Nov  2 20:57:29 2027 GMT
```

The first `subject` line comes from the signing command. The other three lines come from the check. The new certificate has the same subject and issuer as the old one, and it ends in 2027.

## Replace the Secret and restart the server

Write the certificate and key into the Secret `outpost-policy-tls`. The pipe creates the Secret as YAML on the client and applies it, so the existing Secret is updated. Then try the create again:

```sh
kubectl -n webhook-system create secret tls outpost-policy-tls --cert=tls.crt --key=tls.key --dry-run=client -o yaml | kubectl apply -f -
kubectl -n outpost create deployment probe --image=mccutchen/go-httpbin:2.25.0
```

```text
secret/outpost-policy-tls configured
error: failed to create deployment: Internal error occurred: failed calling webhook "outpost-policy.astrona.io": failed to call webhook: Post "https://outpost-policy.webhook-system.svc:443/validate?timeout=5s": tls: failed to verify certificate: x509: certificate has expired or is not yet valid: current time 2026-11-02T20:57:29Z is after 2025-01-08T00:00:00Z
```

The create still fails with the same error. The Secret holds the new certificate, but the running server loaded the old one when it started. The pod must restart to read the Secret again. Restart the Deployment of the webhook server:

```sh
kubectl -n webhook-system rollout restart deployment/outpost-policy
kubectl -n webhook-system rollout status deployment/outpost-policy
kubectl -n webhook-system get pods -l app=outpost-policy
```

```text
deployment.apps/outpost-policy restarted
Waiting for deployment "outpost-policy" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "outpost-policy" rollout to finish: 1 old replicas are pending termination...
deployment "outpost-policy" successfully rolled out
NAME                              READY   STATUS        RESTARTS   AGE
outpost-policy-69c6c7cbf8-2rm82   1/1     Terminating   0          47s
outpost-policy-7c95fc9cf7-4425f   1/1     Running       0          1s
```

The rollout reports success while the old pod is still `Terminating`. A create in this moment can still reach the old pod and fail with the same `x509` error. Wait about ten seconds, then create the Deployment and read the log of the new server:

```sh
kubectl -n outpost create deployment probe --image=mccutchen/go-httpbin:2.25.0
kubectl -n webhook-system logs -l app=outpost-policy
```

```text
deployment.apps/probe created
listening on 8443
POST /validate?timeout=5s uid=bbe7eb20-cb69-4d7c-8dfb-7f7b3a298fb4 allowed
```

The create works, and the new server logged the request. The fix has three parts that depend on each other: a certificate signed by the trusted CA, the right name in the SAN, and a restart so the server loads the Secret.

You can now read an `x509` error, check the dates and the issuer of a certificate with `openssl`, and replace a serving certificate without touching the webhook configuration. Webhooks are one kind of platform component. The next failure has no error message at all: a controller that does not run.

## Common pitfalls

> [!WARNING]
> - **Replacing the Secret and not restarting the server.** The server reads the certificate once, when it starts. The `x509` error stays until the pod restarts.
> - **Signing with a new CA.** The `caBundle` in the webhook configuration trusts the old CA. A certificate from another CA gives `certificate signed by unknown authority`.
> - **Leaving out the SAN.** The API server compares the Service name with the SAN of the certificate. A certificate with only a common name (CN) fails.
> - **Testing right after the rollout.** The old pod is still `Terminating` and can still answer. Wait a few seconds and test again.
> - **Setting `failurePolicy: Ignore`.** The create works, but the policy no longer runs.

# Solution

The three failures are independent. The Service `starfleet-policy` sends traffic to port `8444`, and the webhook server listens on `8443`, so the API server gets `connection refused`. The serving certificate of `outpost-policy` ended on 2025-01-08, so the API server rejects it. The Prometheus Operator is scaled to zero, so the ServiceMonitor and the PrometheusRule never reach Prometheus. Fix them in any order.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-050/module-20/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Fix the Service starfleet-policy

Create a Deployment in `starfleet` and read the error:

```sh
kubectl -n starfleet create deployment test --image=ghcr.io/stefanprodan/podinfo:6.15.0
```

```text
error: failed to create deployment: Internal error occurred: failed calling webhook "starfleet-policy.astrona.io": failed to call webhook: Post "https://starfleet-policy.webhook-system.svc:443/validate?timeout=5s": dial tcp 10.96.204.218:443: connect: connection refused
```

The API server called the Service `starfleet-policy` in `webhook-system` on port `443` and the connection was refused. Check the pods and the EndpointSlices behind the Service:

```sh
kubectl -n webhook-system get pods,endpointslices
```

```text
NAME                                    READY   STATUS    RESTARTS   AGE
pod/outpost-policy-69c6c7cbf8-6hcbw     1/1     Running   0          5m26s
pod/starfleet-policy-5b5c8f84f8-lfqsh   1/1     Running   0          5m26s

NAME                                                    ADDRESSTYPE   PORTS   ENDPOINTS     AGE
endpointslice.discovery.k8s.io/outpost-policy-ntqms     IPv4          8443    10.244.0.11   5m26s
endpointslice.discovery.k8s.io/starfleet-policy-sbl4r   IPv4          8444    10.244.0.9    5m26s
```

This time the Service has an endpoint, so the selector is right. The endpoint port is `8444`, and the other webhook uses `8443`. Compare the Service port with the port the container opens:

```sh
kubectl -n webhook-system get service starfleet-policy -o jsonpath='{.spec.selector}{" "}{.spec.ports}{"\n"}'
kubectl -n webhook-system get pod -l app=starfleet-policy -o jsonpath='{.items[0].spec.containers[0].ports}{"\n"}'
kubectl -n webhook-system logs deploy/starfleet-policy
```

```text
{"app":"starfleet-policy"} [{"port":443,"protocol":"TCP","targetPort":8444}]
[{"containerPort":8443,"protocol":"TCP"}]
listening on 8443
```

The Service sends traffic to `targetPort` `8444`, and the server listens on `8443`. Patch the Service and check the EndpointSlice:

```sh
kubectl -n webhook-system patch service starfleet-policy --type merge -p '{"spec":{"ports":[{"port":443,"targetPort":8443}]}}'
kubectl -n webhook-system get endpointslices
```

```text
service/starfleet-policy patched
NAME                     ADDRESSTYPE   PORTS   ENDPOINTS     AGE
outpost-policy-ntqms     IPv4          8443    10.244.0.11   5m26s
starfleet-policy-sbl4r   IPv4          8443    10.244.0.9    5m26s
```

Prove the fix with a create and with the log of the webhook server:

```sh
kubectl -n starfleet create deployment test --image=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n webhook-system logs deploy/starfleet-policy
kubectl -n starfleet delete deployment test
```

```text
deployment.apps/test created
listening on 8443
POST /validate?timeout=5s uid=adb36306-5278-4978-9246-2e38824c7e0d allowed
deployment.apps "test" deleted from starfleet namespace
```

The watch terminal now shows the check `starfleet-creates` passing. The checks for `outpost` and `scout` still fail.

## Step 2: Replace the certificate of outpost-policy

Create a Deployment in `outpost`. The error is a different one:

```sh
kubectl -n outpost create deployment test --image=ghcr.io/stefanprodan/podinfo:6.15.0
```

```text
error: failed to create deployment: Internal error occurred: failed calling webhook "outpost-policy.astrona.io": failed to call webhook: Post "https://outpost-policy.webhook-system.svc:443/validate?timeout=5s": tls: failed to verify certificate: x509: certificate has expired or is not yet valid: current time 2026-11-02T21:16:52Z is after 2025-01-08T00:00:00Z
```

The connection works, and the API server rejects the certificate. Confirm the expiry date and the issuer:

```sh
kubectl -n webhook-system get secret outpost-policy-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer -enddate
```

```text
subject=CN=outpost-policy.webhook-system.svc
issuer=CN=starfleet-webhook-ca
notAfter=Jan  8 00:00:00 2025 GMT
```

The CA `starfleet-webhook-ca` is in the Secret `webhook-ca`, and the webhook configuration already trusts it. Sign a new certificate with that CA. Work in an empty directory:

```sh
mkdir certs && cd certs
kubectl -n webhook-system get secret webhook-ca -o jsonpath='{.data.tls\.crt}' | base64 -d > ca.crt
kubectl -n webhook-system get secret webhook-ca -o jsonpath='{.data.tls\.key}' | base64 -d > ca.key
openssl req -newkey rsa:2048 -nodes -keyout tls.key -out tls.csr -subj "/CN=outpost-policy.webhook-system.svc"
```

The `openssl req` command prints progress dots, which are left out here. Save this as `san.ext`:

```text
subjectAltName=DNS:outpost-policy.webhook-system.svc
extendedKeyUsage=serverAuth
```

Sign the request, store the result in the Secret, and restart the webhook server so that it loads the new certificate:

```sh
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 365 -extfile san.ext -out tls.crt
kubectl -n webhook-system create secret tls outpost-policy-tls --cert=tls.crt --key=tls.key --dry-run=client -o yaml | kubectl apply -f -
kubectl -n webhook-system rollout restart deployment/outpost-policy
kubectl -n webhook-system rollout status deployment/outpost-policy
```

```text
Certificate request self-signature ok
subject=CN=outpost-policy.webhook-system.svc
secret/outpost-policy-tls configured
deployment.apps/outpost-policy restarted
Waiting for deployment "outpost-policy" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "outpost-policy" rollout to finish: 1 old replicas are pending termination...
deployment "outpost-policy" successfully rolled out
```

The old pod can still answer for a few seconds after the rollout, and a create in that moment fails with the same `x509` error. Wait about ten seconds, then prove the fix:

```sh
kubectl -n outpost create deployment test --image=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n outpost delete deployment test
```

```text
deployment.apps/test created
deployment.apps "test" deleted from outpost namespace
```

The watch terminal now shows the check `outpost-creates` passing.

## Step 3: Bring the Prometheus Operator back

Both objects for `scout` exist, and Prometheus does not know them. Ask Prometheus from `shuttle`:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -G http://kps-prometheus.monitoring:9090/api/v1/query --data-urlencode 'query=up{job="scout"}'
kubectl -n starfleet exec deploy/shuttle -- curl -s http://kps-prometheus.monitoring:9090/api/v1/rules
```

```text
{"status":"success","data":{"resultType":"vector","result":[]}}
{"status":"success","data":{"groups":[]}}
```

The target is unknown and no rule is loaded. The component that moves the ServiceMonitor and the PrometheusRule into Prometheus is the operator. Read its Deployment, scale it to one replica and wait for the rollout:

```sh
kubectl -n monitoring get deployment kps-operator
kubectl -n monitoring scale deployment/kps-operator --replicas=1
kubectl -n monitoring rollout status deployment/kps-operator
```

```text
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
kps-operator   0/0     0            0           5m54s
deployment.apps/kps-operator scaled
Waiting for deployment "kps-operator" rollout to finish: 0 of 1 updated replicas are available...
deployment "kps-operator" successfully rolled out
```

Wait about a minute for Prometheus to load the configuration, then repeat the two queries from the start of this step. The first answer returns the series with the value `"1"`, and the second lists the rule `ScoutDown`.

The watch terminal shows all four checks passing. Press Ctrl-C to stop the watch, then submit once:

```sh
astrona submit -c sections/section-050/module-20/labs/lab-01
```

## Why the shortcuts fail

Setting `failurePolicy: Ignore` on a webhook makes the create work, but the API server skips the webhook. The grader checks the field and the log of the webhook server. Deleting a webhook configuration removes the policy, and the grader checks that both configurations exist. Deleting the ServiceMonitor or the PrometheusRule removes the thing that the operator should reconcile, and the grader checks that both still exist.

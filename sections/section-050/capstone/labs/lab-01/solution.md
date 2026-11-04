# Solution

The four faults are independent. `cargo` has a memory limit of `48Mi` and the process holds about `150Mi`, so the kernel stops it. `beacon` names the image tag `v6.15.0`, which does not exist. `probe` has a liveness probe on port `8081`, and the server listens on `8080`. The Service `starfleet-policy` selects pods with the label `app=starfleet-policy-v2`, and the webhook pod has the label `app=starfleet-policy`, so the Service has no endpoints. Fix them in any order.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-050/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Read the state of the pods

List the pods and the warning events of the namespace:

```sh
kubectl -n starfleet get pods
kubectl -n starfleet get events --field-selector type=Warning --sort-by=.lastTimestamp
```

The status column shows `OOMKilled` or `CrashLoopBackOff` for `cargo`, `ImagePullBackOff` or `ErrImagePull` for `beacon`, and restarts for `probe`. The events give the first hints: a pull error for `beacon`, `Liveness probe failed` for `probe` and only `BackOff` for `cargo`. The reason for `cargo` is in its last state.

## Step 1: Fix cargo

Print the last state and the limit of the container:

```sh
kubectl -n starfleet describe pod -l app=cargo | sed -n '/State:/,/Ready:/p;/Limits/,/Requests/p'
```

The last state is `Terminated` with the reason `OOMKilled` and exit code `137`, and the limit is `48Mi`. Give the container a limit high enough to run, read its real use, then set a limit that fits:

```sh
kubectl -n starfleet set resources deployment/cargo --limits=memory=512Mi
kubectl -n starfleet rollout status deployment/cargo --timeout=120s
kubectl -n starfleet top pod --containers -l app=cargo
```

The process uses between about `150Mi` and `230Mi`. Wait about 30 seconds if `kubectl top` says that metrics are not available yet. A limit of `320Mi` is about 1.4 times the highest reading. Set it and the request:

```sh
kubectl -n starfleet set resources deployment/cargo --limits=memory=320Mi --requests=memory=256Mi
kubectl -n starfleet rollout status deployment/cargo --timeout=120s
```

Do not remove the limit. The grader needs a limit between `256Mi` and `1Gi`.

## Step 2: Fix beacon

Read the pull error:

```sh
kubectl -n starfleet describe pod -l app=beacon | sed -n '/^Events/,$p'
```

The event says `Failed to pull image "ghcr.io/stefanprodan/podinfo:v6.15.0"` and `not found`. The repository exists, but the tag does not. Use the tag `6.15.0`:

```sh
kubectl -n starfleet set image deployment/beacon beacon=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n starfleet rollout status deployment/beacon --timeout=120s
```

## Step 3: Fix probe

Read the events of the pod:

```sh
kubectl -n starfleet describe pod -l app=probe | sed -n '/Liveness/p;/^Events/,$p'
```

The probe line shows `http-get http://:8081/status/200`, and the events say `Liveness probe failed` with `connection refused`. Nothing listens on port `8081`. The container port is named `http` and is `8080`. Save this as `probe-liveness-fix.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
        - name: probe
          livenessProbe:
            httpGet:
              path: /status/200
              port: http
```

Apply it and wait for the rollout:

```sh
kubectl -n starfleet patch deployment probe --patch-file probe-liveness-fix.yaml
kubectl -n starfleet rollout status deployment/probe --timeout=120s
```

## Step 4: Fix the webhook

Create a Deployment in `starfleet` and read the error:

```sh
kubectl -n starfleet create deployment test --image=ghcr.io/stefanprodan/podinfo:6.15.0
```

The error says `failed calling webhook "starfleet-policy.astrona.io"` and names the Service `starfleet-policy.webhook-system.svc` on port `443`, with `connection refused`. Compare the selector of the Service with the labels of the pods behind it:

```sh
kubectl -n webhook-system get pods --show-labels
kubectl -n webhook-system get endpointslices
kubectl -n webhook-system get service starfleet-policy -o jsonpath='{.spec.selector}{"\n"}'
```

The pod has `app=starfleet-policy`, the EndpointSlice of the Service has no endpoints, and the selector is `{"app":"starfleet-policy-v2"}`. Patch the Service. Do not delete the webhook configuration and do not set `failurePolicy: Ignore`:

```sh
kubectl -n webhook-system patch service starfleet-policy --type merge -p '{"spec":{"selector":{"app":"starfleet-policy"}}}'
kubectl -n starfleet create deployment test --image=ghcr.io/stefanprodan/podinfo:6.15.0
kubectl -n webhook-system logs deploy/starfleet-policy
```

The create works, and the log of the webhook server shows a new `POST /validate` line that ends in `allowed`. Remove the test Deployment:

```sh
kubectl -n starfleet delete deployment test
```

## Prove the recovery

Send a request from `shuttle` to each Service:

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://probe:8080/
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://cargo:8080/
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://beacon:9898/
kubectl -n starfleet get pods
```

Each request prints `200`. All pods are `Ready` and the restart counts stay the same when you run `kubectl get pods` again after about 30 seconds.

Press Ctrl-C to stop the watch, then submit your work for grading once:

```sh
astrona submit -c sections/section-050/capstone/labs/lab-01
```

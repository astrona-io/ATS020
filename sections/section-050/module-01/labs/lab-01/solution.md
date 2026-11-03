# Solution

The four pods fail for four different reasons. `scout` asks for a node label that no node has, so the scheduler cannot place it. `probe` has a liveness probe on a port the server does not open, so the kubelet restarts it. `cargo` has a memory limit that is too low, so the kernel stops it. `beacon` names an image tag that does not exist, so the kubelet cannot pull it.

## Read the state of the pods

List the pods:

```sh
kubectl -n starfleet get pods
```

```text
NAME                       READY   STATUS             RESTARTS      AGE
beacon-7876887b8-q8m6h     0/1     ErrImagePull       0             60s
cargo-7959db49c8-jhtsb     0/1     OOMKilled          3 (46s ago)   60s
probe-5fcbfcdfb4-rrbcb     0/1     CrashLoopBackOff   3 (20s ago)   60s
scout-7655b58547-mchss     0/1     Pending            0             60s
shuttle-79b9fbf7c8-sl76w   1/1     Running            0             8m7s
```

The status column gives a first hint for each pod. The events and the container state give the cause. Read the events of the namespace, newest last, and keep only warnings:

```sh
kubectl -n starfleet get events --field-selector type=Warning --sort-by=.lastTimestamp
```

The output is long. These are the decisive lines, shortened:

```text
Warning   FailedScheduling   pod/scout-...   0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector. ...
Warning   Failed             pod/beacon-...  Failed to pull image "ghcr.io/stefanprodan/podinfo:v6.15.0": rpc error: code = NotFound ...
Warning   Unhealthy          pod/probe-...   Liveness probe failed: Get "http://10.244.0.18:8081/status/200": dial tcp 10.244.0.18:8081: connect: connection refused
Warning   BackOff            pod/cargo-...   Back-off restarting failed container cargo in pod ...
```

The `cargo` event only says the container restarts. It does not say why. Step 3 finds the reason.

## Step 1: Fix scout

The scheduler event says the node does not match the pod's node selector. Read the selector:

```sh
kubectl -n starfleet describe pod -l app=scout | grep 'Node-Selectors'
```

```text
Node-Selectors:              disktype=ssd
```

The single node has no `disktype=ssd` label, so the pod stays `Pending`. The task does not ask you to label the node. Remove the selector from the Deployment:

```sh
kubectl -n starfleet patch deploy scout --type=json \
  -p '[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
```

Submit to check:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-01
```

The check `scout-running` now passes. The others still fail.

## Step 2: Fix probe

The event shows the liveness probe sends its request to port `8081`. The server listens on port `8080`, so the connection is refused. The kubelet restarts the container after two failed probes. Read the probe:

```sh
kubectl -n starfleet describe pod -l app=probe | grep 'Liveness'
```

```text
    Liveness:     http-get http://:8081/status/200 delay=3s timeout=1s period=5s successThreshold=1 failureThreshold=2
```

Point the probe at the named container port `http`. Do not remove the probe, because the grader checks that it is still there:

```sh
kubectl -n starfleet patch deploy probe --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/port","value":"http"}]'
```

The new pod must stay up. The check `probe-stable` waits about 25 seconds and fails if the restart count grows.

## Step 3: Fix cargo

The events only show `BackOff`. Read the last state of the container:

```sh
kubectl -n starfleet describe pod -l app=cargo | sed -n '/Last State/,/Ready:/p;/Limits/,/Requests/p'
```

The container shows `Reason: OOMKilled` and `Exit Code: 137`. The memory limit is `48Mi`. The log is empty, because the kernel stopped the process without a message.

The process holds 150 MiB in memory, so a limit of `48Mi` is too low. Removing the limit would also make the pod run, but the grader rejects that. Set a request and a limit that fit the use:

```sh
kubectl -n starfleet set resources deploy/cargo --limits=memory=320Mi --requests=memory=256Mi
```

The grader accepts any limit from `256Mi` up to `1Gi`.

## Step 4: Fix beacon

The event says the image `ghcr.io/stefanprodan/podinfo:v6.15.0` was not found. The tag is `6.15.0`, without the `v`. Set the right image:

```sh
kubectl -n starfleet set image deploy/beacon '*=ghcr.io/stefanprodan/podinfo:6.15.0'
```

Do not use `latest`. The grader checks for the exact tag.

## Prove the fixes

Wait about a minute, then list the pods:

```sh
kubectl -n starfleet get pods
```

```text
NAME                       READY   STATUS    RESTARTS   AGE
beacon-84d59856bb-cqjbh    1/1     Running   0          60s
cargo-5949995855-qp6sq     1/1     Running   0          60s
probe-69fb974b64-lvkpr     1/1     Running   0          61s
scout-5c56bc4d57-b9nxk     1/1     Running   0          61s
shuttle-79b9fbf7c8-sl76w   1/1     Running   0          13m
```

Send a request to each Service from `shuttle`:

```sh
for target in scout:9898 probe:8080 cargo:8080 beacon:9898; do
  kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w "$target %{http_code}\n" http://$target/
done
```

Each line must end in `200`. Then submit:

```sh
astrona submit -c sections/section-050/module-01/labs/lab-01
```

```text
  PASS  scout-running (0.17s)
  PASS  probe-stable (25.30s)
  PASS  cargo-limit (0.23s)
  PASS  beacon-image (0.14s)
  PASS  design-intact (0.33s)

5 passed, 0 failed in 26.17s
Score: 5/5 points (100%)
```

## Wrong fixes the grader rejects

- Deleting the liveness probe of `probe`: the pod stays up, but the check for the probe fails.
- Removing the memory limit of `cargo`, or changing its command: the limit check or the design check fails.
- Using `latest` for `beacon`: the check needs the exact tag `6.15.0`.
- Deleting a Deployment or scaling it to zero: the design check fails.

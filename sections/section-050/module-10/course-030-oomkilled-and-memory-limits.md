# OOMKilled And Memory Limits

Some failures leave no message at all. A container that uses more memory than its limit does not print an error. The kernel stops it, and the log ends in the middle of the work. This part shows where Kubernetes records such a kill, how to measure what the process really needs, and how to set a limit that fits. It uses the Deployment `cargo`.

The commands need the playground as it starts: the Deployment `cargo` in `starfleet`, with a memory limit of `64Mi`, and the metrics-server add-on.

## What OOMKilled means

A memory limit is the most memory a container may use. A request is only used for scheduling, but a limit is enforced by the Linux kernel on the node. When the processes of a container grow past the limit, the kernel's out-of-memory killer (OOM killer) sends `SIGKILL` to one of them. The kubelet sees the container end and records the reason `OOMKilled` with exit code `137`, which is `128 + 9`.

Start with the pod. Print the current state, the last state and the limit, and the events:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet describe pod -l app=cargo | sed -n '/State:/,/Ready:/p;/Limits/,/Requests/p;/^Events/,$p'
```

```text
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
      Started:      Mon, 02 Nov 2026 21:21:49 +0100
      Finished:     Mon, 02 Nov 2026 21:21:49 +0100
    Ready:          False
    Limits:
      memory:  64Mi
    Requests:
Events:
  Type     Reason     Age                    From               Message
  ----     ------     ----                   ----               -------
  Normal   Scheduled  5m24s                  default-scheduler  Successfully assigned starfleet/cargo-666d87f89d-krbgj to astro-ats-020-playground-050-01-control-plane
  Normal   Pulled     2m32s (x6 over 5m23s)  kubelet            spec.containers{cargo}: Container image "node:22-alpine" already present on machine and can be accessed by the pod
  Normal   Created    2m32s (x6 over 5m23s)  kubelet            spec.containers{cargo}: Container created
  Normal   Started    2m32s (x6 over 5m23s)  kubelet            spec.containers{cargo}: Container started
  Warning  BackOff    62s (x8 over 5m21s)    kubelet            spec.containers{cargo}: Back-off restarting failed container cargo in pod cargo-666d87f89d-krbgj_starfleet(774d2493-54f8-4d98-9c93-515cd0c13eaf)
```

The cause is in the last state, not in the events. The reason is `OOMKilled`, the exit code is `137`, and the container ran for less than a second. The events only say `BackOff`, so a check of the events alone sends you to the wrong place. The log is empty too:

```sh
kubectl -n starfleet logs deploy/cargo --previous
```

The command prints nothing. The process was killed before it wrote a line. An empty log with exit code `137` is the mark of a kill by `SIGKILL`.

## Measure before you set a limit

You do not guess a limit. You read what the process uses. The metrics-server add-on collects the memory use of each container from the kubelet, and `kubectl top` shows it. A pod that is killed at once has no measurement, so the command fails:

```text
Error from server (NotFound): podmetrics.metrics.k8s.io "starfleet/cargo-666d87f89d-krbgj" not found
```

That is the output of `kubectl -n starfleet top pod cargo-666d87f89d-krbgj`. First give the container a limit high enough to run. Set `512Mi`, wait for the new pod, and read the use:

```sh
kubectl -n starfleet set resources deployment/cargo --limits=memory=512Mi
kubectl -n starfleet rollout status deployment/cargo --timeout=90s
kubectl -n starfleet top pod --containers -l app=cargo
```

```text
deployment.apps/cargo resource requirements updated
deployment "cargo" successfully rolled out
POD                      NAME    CPU(cores)   MEMORY(bytes)
cargo-665c7f84d5-q4gbx   cargo   1m           222Mi
```

The `rollout status` command printed some "Waiting" lines first, which are left out here. The metrics-server needs about half a minute after the pod starts, so run the `top` command again if it says that metrics are not available yet. The container uses `222Mi`. This number is the working set of the container, which includes memory that the kernel can give back, so it changes between readings. It was `159Mi` in a later reading on the same pod template.

## Size the limit

A good limit is above the highest use you see, with room for a peak. A limit equal to the use kills the container at the first peak. A limit far above the use hides leaks and wastes space on the node. A common start is 1.3 to 1.5 times the highest reading. Here `320Mi` is about 1.4 times `222Mi`. Set the request to the typical use, so the scheduler reserves what the container needs:

```sh
kubectl -n starfleet set resources deployment/cargo --limits=memory=320Mi --requests=memory=256Mi
kubectl -n starfleet rollout status deployment/cargo --timeout=90s
```

```text
deployment.apps/cargo resource requirements updated
deployment "cargo" successfully rolled out
```

Wait about 40 seconds. Then prove the fix with the state of the pod, the real use, the stored limit, a request from `shuttle` and the restart count:

```sh
kubectl -n starfleet get pods -l app=cargo
kubectl -n starfleet top pod -l app=cargo
kubectl -n starfleet get deploy cargo -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl -n starfleet exec deploy/shuttle -- curl -s --max-time 3 http://cargo:8080/
kubectl -n starfleet get pod -l app=cargo -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}{"\n"}'
```

```text
NAME                     READY   STATUS    RESTARTS   AGE
cargo-5949995855-79gs2   1/1     Running   0          41s
NAME                     CPU(cores)   MEMORY(bytes)
cargo-5949995855-79gs2   0m           159Mi
{"limits":{"memory":"320Mi"},"requests":{"cpu":"10m","memory":"256Mi"}}
cargo holds 157286400 bytes
0
```

The pod is `Running`, the use is below the limit, the answer is the string the server returns, and the restart count is `0`. The answer says the process holds `157286400` bytes, which is 150 MiB, so a limit of `64Mi` could never work.

Removing the limit would also stop the kills. It is the wrong fix. A container with no limit can take all the memory of the node, and the kernel then kills other pods. You size the limit and keep it.

You can now find an `OOMKilled` container from its last state, measure what it needs and set a limit that fits. The cause here was inside the cluster. The last fault family has a cause outside it: the image that the node must pull.

## Common pitfalls

> [!WARNING]
> - **Looking for OOM in the events.** The kernel kills the container, so no event names it. Read `Last State` in `kubectl describe pod`.
> - **Setting the limit equal to the use.** The first peak kills the container again. Leave headroom.
> - **Removing the limit.** It hides the fault and puts the node at risk.
> - **Running `kubectl top` too early.** The metrics-server needs about half a minute after the pod starts.

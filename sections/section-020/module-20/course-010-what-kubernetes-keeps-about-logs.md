# What Kubernetes Keeps About Logs

Read container output and pod events as separate evidence. `kubectl logs` reads application output; events describe Kubernetes actions such as image pulls and restarts. Use `--previous` when the failure belongs to an earlier container instance.

## Read the log of a running pod

A **log** is the text a program writes to its standard output (stdout) and standard error (stderr). The container runtime on the node captures both streams and keeps them in files. The `kubectl logs` command asks the kubelet, the agent on the node, to read those files and send them back through the API server.

`probe` in the namespace `outpost` is a pod of `go-httpbin`. It writes one line for every request it serves. Read the last three lines:

<!-- astrona:playground:renew -->

```sh
kubectl -n outpost logs deploy/probe --tail=3
```

You should see lines like these. The timestamps will differ:

```text
time=2026-11-02T19:35:58.194Z level=INFO msg="200 GET /get 0.2ms" status=200 method=GET uri=/get route="GET /get" size_bytes=254 duration_ms=0.16725099999999998 user_agent=curl/8.22.0 client_ip=10.244.0.14 request_size_bytes=0
time=2026-11-02T19:35:58.200Z level=ERROR msg="500 GET /status/500 0.1ms" status=500 method=GET uri=/status/500 route=/status/{code} size_bytes=0 duration_ms=0.056042 user_agent=curl/8.22.0 client_ip=10.244.0.14 request_size_bytes=0
time=2026-11-02T19:35:59.213Z level=INFO msg="200 GET /get 0.1ms" status=200 method=GET uri=/get route="GET /get" size_bytes=254 duration_ms=0.065084 user_agent=curl/8.22.0 client_ip=10.244.0.14 request_size_bytes=0
```

Each line is in logfmt, a list of `key=value` pairs. The pair `level=ERROR` marks the second line as a failed request. The `shuttle` pod in `starfleet` sends this traffic: one request to `probe` every second and a request for `/status/500` every fourth second.

## Read the log of a container that crashed

A crashing container is the case where logs matter most. The kubelet restarts a container that exits, and the new container starts with a new log. The log of the container that died is still available for a short time, with the `--previous` flag.

Start a pod that writes two lines, waits 20 seconds and then exits with code 1. Its `restartPolicy` is `Always`, so the kubelet restarts it:

```sh
kubectl -n outpost run crasher --image=curlimages/curl:8.22.0 --restart=Always \
  --command -- sh -c 'echo "booting"; echo "fatal: cannot open /etc/app.conf" >&2; sleep 20; exit 1'
```

Wait about 25 seconds, until the column `RESTARTS` shows `1`:

```sh
kubectl -n outpost get pod crasher
```

You should see:

```text
NAME      READY   STATUS    RESTARTS     AGE
crasher   1/1     Running   1 (4s ago)   25s
```

The container has now run twice. `kubectl logs` shows the current container, which has just started and has written its two lines again. The flag `--previous` shows the container that exited:

```sh
kubectl -n outpost logs crasher
kubectl -n outpost logs crasher --previous
```

Both commands print the two lines of the container they read. The order of the stdout line and the stderr line can differ between the two outputs:

```text
booting
fatal: cannot open /etc/app.conf
```

The pod object also records why the first container ended. The field `lastState.terminated` holds the exit code and the reason:

```sh
kubectl -n outpost get pod crasher -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'
```

You should see:

```text
{"containerID":"containerd://a005a8e48a0c023ae46d00a6808bf4add40186985213e6a7d7699f1cae263fbe","exitCode":1,"finishedAt":"2026-11-02T19:36:20Z","reason":"Error","startedAt":"2026-11-02T19:36:00Z"}
```

The exit code `1` and the reason `Error` say that the program itself failed. The log says why: it could not open `/etc/app.conf`.

## Read the events

A log is written by the program. An **event** is written by Kubernetes. It is a short record about an object, such as "the scheduler placed this pod on a node" or "the kubelet started the container". Events answer questions the program cannot answer, for example why a pod never started. Read the events of the pod:

```sh
kubectl -n outpost events --for pod/crasher
```

You should see:

```text
LAST SEEN          TYPE     REASON      OBJECT        MESSAGE
25s                Normal   Scheduled   Pod/crasher   Successfully assigned outpost/crasher to astro-ats-020-playground-020-02-control-plane
3s (x2 over 24s)   Normal   Pulled      Pod/crasher   Container image "curlimages/curl:8.22.0" already present on machine and can be accessed by the pod
3s (x2 over 24s)   Normal   Created     Pod/crasher   Container created
3s (x2 over 24s)   Normal   Started     Pod/crasher   Container started
```

The `x2` shows that the kubelet created and started the container twice. If the pod keeps crashing, a `Warning` event with the reason `BackOff` appears, because the kubelet waits longer before each restart. Events are kept for about one hour by default, so they also disappear.

## Where the built-in tools stop

The previous output shows the limits. These limits are the reason a log pipeline exists:

- The kubelet keeps the log of only the last terminated container. After a short time the node also removes that container, and `kubectl logs --previous` fails with "unable to retrieve container logs".
- When a pod is deleted, its log files are deleted with it.
- `kubectl logs` reads one pod at a time. It cannot answer "how many error lines did all pods in `outpost` write in the last ten minutes?".
- A log line is plain text. You cannot alert on it or draw it on a dashboard until something turns it into a metric.

A log pipeline reads the log files on every node as they are written, adds the pod, namespace and deployment to each line, and sends the result to a place that outlives the pod. In this module, the OpenTelemetry Collector is that pipeline, and it ends in a Prometheus metric. The open question is where the files are and how a program reads them.

Remove the test pod before you continue:

```sh
kubectl -n outpost delete pod crasher
```

## Common pitfalls

> [!WARNING]
> - **Running `--previous` too late.** The previous container is removed after a short time. Read it right after the restart.
> - **Reading `kubectl logs` on a pod that never started.** There is no container and no log. Read `kubectl events --for pod/<name>` and `kubectl describe pod <name>` instead.
> - **Forgetting the namespace.** `kubectl logs deploy/probe` looks in `default`. Add `-n outpost`.
> - **Trusting an old event.** Events are kept for about one hour. A pod that failed yesterday has no events today.

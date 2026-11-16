# Repair A Failing Liveness Probe

The `probe` process serves requests, but the kubelet restarts it because its health check fails. A liveness failure restarts a container; a readiness failure removes it from Service traffic. Read the events before changing either check.

## Compare the check with the server


A liveness probe is a check that the kubelet runs against a container on a schedule. When it fails more times in a row than `failureThreshold`, the kubelet kills the container and restarts it. `probe` runs `go-httpbin`, which works, but its probe asks for `/healthz`, a path the server does not have. Look at the last state, the probe and the events:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet describe pod -l app=probe | sed -n '/Liveness/p;/Last State/,/Ready:/p;/^Events/,$p'
```

```text
    Last State:     Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 02 Nov 2026 21:19:28 +0100
      Finished:     Mon, 02 Nov 2026 21:19:38 +0100
    Ready:          False
    Liveness:     http-get http://:http/healthz delay=3s timeout=1s period=5s successThreshold=1 failureThreshold=2
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  59s                default-scheduler  Successfully assigned starfleet/probe-5589b495bc-nbt6g to astro-ats-020-playground-050-01-control-plane
  Normal   Pulled     28s (x4 over 58s)  kubelet            spec.containers{probe}: Container image "mccutchen/go-httpbin:2.26.0" already present on machine and can be accessed by the pod
  Normal   Created    28s (x4 over 58s)  kubelet            spec.containers{probe}: Container created
  Normal   Started    28s (x4 over 58s)  kubelet            spec.containers{probe}: Container started
  Warning  Unhealthy  18s (x8 over 53s)  kubelet            spec.containers{probe}: Liveness probe failed: HTTP probe failed with statuscode: 404
  Warning  Unhealthy  18s (x8 over 53s)  kubelet            spec.containers{probe}: Liveness probe failed: HTTP probe failed with statuscode: 404
  Normal   Killing    18s (x4 over 48s)  kubelet            spec.containers{probe}: Container probe failed liveness probe, will be restarted
  Warning  BackOff    18s (x2 over 18s)  kubelet            spec.containers{probe}: Back-off restarting failed container probe in pod probe-5589b495bc-nbt6g_starfleet(bb7297a4-ba86-4020-8b65-6fca2112a56a)
```

Three facts point to the probe. The exit code is `0`, because `go-httpbin` shuts down cleanly when the kubelet sends `SIGTERM`. The events say `Liveness probe failed` with status code `404`. The event `Killing` says that the kubelet restarts the container because of the probe. A crash would show a non-zero exit code and no `Unhealthy` events.

The log of the previous run confirms that the server is fine and that the kubelet was the caller:

```sh
kubectl -n starfleet logs deploy/probe --previous | tail -5
```

```text
time=2026-11-02T20:20:51.100Z level=INFO msg="go-httpbin listening on http://0.0.0.0:8080"
time=2026-11-02T20:20:58.106Z level=WARN msg="404 GET /healthz 0.1ms" status=404 method=GET uri=/healthz route="" size_bytes=19 duration_ms=0.054833999999999994 user_agent=kube-probe/1.35 client_ip=10.244.0.1 request_size_bytes=0
time=2026-11-02T20:21:03.105Z level=WARN msg="404 GET /healthz 0.0ms" status=404 method=GET uri=/healthz route="" size_bytes=19 duration_ms=0.035500000000000004 user_agent=kube-probe/1.35 client_ip=10.244.0.1 request_size_bytes=0
time=2026-11-02T20:21:03.118Z level=INFO msg="shutting down ..."
```

The user agent `kube-probe/1.35` is the kubelet. The server answered `404` twice, which equals `failureThreshold: 2`, and then shut down. The fix is to point the probe at a path the server serves. Removing the probe also stops the restarts, but it hides the problem, so you change the path. Save this as `probe-liveness-fix.yaml`. It is a patch that the Deployment merges into the container named `probe`:

```yaml
spec:
  template:
    spec:
      containers:
        - name: probe
          livenessProbe:
            httpGet:
              path: /status/200
```

Apply it, wait for the new pod, and send a request from `shuttle`:

```sh
kubectl -n starfleet patch deployment probe --patch-file probe-liveness-fix.yaml
kubectl -n starfleet rollout status deployment/probe --timeout=90s
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://probe:8080/
```

```text
deployment.apps/probe patched
deployment "probe" successfully rolled out
200
```

Wait about 30 seconds and list the pods of `probe`. The restart count must stay `0`, because a probe that passes does not restart the container:

```text
NAME                     READY   STATUS    RESTARTS   AGE
probe-69fb974b64-778kf   1/1     Running   0          31s
```

A path the server answers with `200` ends the loop. The same reading works for a readiness probe, which decides whether the Service sends requests to the pod. A failing readiness probe does not restart the container. It keeps the pod at `0/1` in the `READY` column, with the same `Unhealthy` event.


The lab changes the probe port instead of its path. Compare the declared container port, the server log and the probe endpoint before editing. Keep the liveness check enabled.


## Common pitfalls

> [!WARNING]
> - Exit code zero does not prove that a long-running service stayed healthy.
> - Check both path and port; a healthy process can receive the wrong probe.
> - Observe the replacement for more than one probe interval before declaring it stable.

## Your mission: Repair A Failing Liveness Probe

The `probe` Deployment in `starfleet` is unhealthy. The `shuttle` client and the Service `probe` are available for testing.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-050-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-10/labs/lab-02
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-050/module-10/labs/lab-02
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-050-01-02
astrona start ats-020-playground-050-01
```

# Raise An Undersized Memory Request

The `probe` workload runs, but its memory request is below the memory it uses. A request controls scheduling; it is not a memory cap. The node can admit more work than it can safely support if requests consistently understate use.

Measure current usage and read the configured request:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet top pods -l app=probe
kubectl -n starfleet get deployment probe -o json | jq '.spec.template.spec.containers[].resources'
```

For a peak over the retained history, forward Prometheus in another terminal:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Then query the working set:

```sh
curl -fsSG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=max(max_over_time(container_memory_working_set_bytes{namespace="starfleet",container="probe"}[30m]))' | jq .data.result
```

The value is bytes. Divide by `1024 * 1024` to compare it with a request in mebibytes (`Mi`). A fresh cluster has only the samples collected since startup, even when the query asks for thirty minutes.

Choose a request above the observed peak, leaving room for variation. The reference value of `24Mi` suits the fixture's small process; measure before using it elsewhere. Keep the CPU request and memory limit intact:

```sh
kubectl -n starfleet set resources deployment/probe --requests=cpu=5m,memory=24Mi
kubectl -n starfleet rollout status deployment/probe
kubectl -n starfleet get pods -l app=probe
kubectl -n starfleet top pods -l app=probe
```

Check that the replacement is ready, has no new restarts, and still serves HTTP. The independent lab seeds only the undersized memory request; `scout` is already sized appropriately.


## Common pitfalls

> [!WARNING]
> - A low request does not itself cause OOMKilled; inspect limits and termination reasons separately.
> - Do not set a request above its limit.
> - Keep workload replicas and the traffic source unchanged.
> - A short test does not capture daily or seasonal peaks.

## Your mission: Raise An Undersized Memory Request

The `probe` Deployment in `starfleet` has a resource request that does not match its usage. The other workload starts with suitable requests.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-040-02
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-20/labs/lab-03
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-040/module-20/labs/lab-03
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-040-02-03
astrona start ats-020-playground-040-02
```

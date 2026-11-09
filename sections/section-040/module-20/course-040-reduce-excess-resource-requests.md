# Reduce Excess Resource Requests

A ratio at one moment is not enough to change a request. The request must cover the highest usage the container reaches, with some room, and it must not be far above it. Measure the peak, choose smaller requests for `scout`, and verify that its replicas still serve traffic.

## Rank the gap over a time range

The peak usage of a container is the highest value it reached in a window. The function `max_over_time()` returns the highest value of each series over a range. For memory, it works directly on the gauge. For CPU, the counter must become a rate first, and a subquery `[30m:30s]` evaluates that rate every 30 seconds over the last 30 minutes so `max_over_time()` can run on it.

Open a port-forward to Prometheus and define the helper that runs a query:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 &
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.endpoint, .instance, .job, .service, .namespace)), value: .value[1]}'
}
```

Divide the request of each container by its peak memory over 30 minutes. The `max by (container)` keeps one value for each container name, because the replicas of a Deployment have the same request:

```sh
promql 'max by (container) (kube_pod_container_resource_requests{namespace="starfleet",resource="memory",container!=""}) / max by (container) (max_over_time(container_memory_working_set_bytes{namespace="starfleet",container!=""}[30m]))'
```

```text
{"metric":{"container":"shuttle"},"value":"1.8115877930119417"}
{"metric":{"container":"scout"},"value":"7.608079869979104"}
{"metric":{"container":"probe"},"value":"0.4501098901098901"}
```

Do the same for CPU, with the subquery:

```sh
promql 'max by (container) (kube_pod_container_resource_requests{namespace="starfleet",resource="cpu",container!=""}) / max by (container) (max_over_time(rate(container_cpu_usage_seconds_total{namespace="starfleet",container!=""}[2m])[30m:30s]))'
```

```text
{"metric":{"container":"shuttle"},"value":"0.6334101374783048"}
{"metric":{"container":"scout"},"value":"86.36089539945876"}
{"metric":{"container":"probe"},"value":"0.3725178852469936"}
```

The workload with the biggest gap is `scout`. It requests 7.6 times its peak memory and 86 times its peak CPU. The workload `probe` is under-provisioned for both: its ratios are below `1`, so it peaks above what it asked for. The client `shuttle` is close to its request and not worth changing.

## Choose new requests

A common rule is to set the request a little above the peak, so the container has room and the scheduler still reserves a realistic amount. For memory, also keep a limit above the request. A container that goes over its memory limit is stopped, so the limit must leave room for a spike. Read the peaks of the two workloads first:

```sh
promql 'max by (container) (max_over_time(container_memory_working_set_bytes{namespace="starfleet",container=~"scout|probe"}[30m]))'
promql 'max by (container) (max_over_time(rate(container_cpu_usage_seconds_total{namespace="starfleet",container=~"scout|probe"}[2m])[30m:30s]))'
```

```text
{"metric":{"container":"probe"},"value":"9318400"}
{"metric":{"container":"scout"},"value":"35282944"}
{"metric":{"container":"probe"},"value":"0.002684434867702961"}
{"metric":{"container":"scout"},"value":"0.002894828716673621"}
```

The sample peak for `scout` is about `34Mi` and `3m` CPU. Requests of `64Mi` and `10m` leave room above that observed peak. Use your own measurements: startup spikes and traffic can change the result.

Apply the new requests and wait for the rollout:

```sh
kubectl -n starfleet set resources deployment/scout --requests=cpu=10m,memory=64Mi --limits=memory=128Mi
kubectl -n starfleet rollout status deployment/scout
kubectl -n starfleet get pods -l app=scout
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout:9898/
```

Query requests and usage again after Prometheus scrapes the replacement pods. Both scout replicas must remain ready. Reducing a request changes the scheduler's reservation; it does not reduce the application's actual memory use.


## Common pitfalls

> [!WARNING]
> - Use peaks over a representative interval, not one `kubectl top` sample.
> - Keep the request above observed usage with room for variation.
> - Do not reduce replicas or remove requests to make the reservation total smaller.
> - Check the running pods and traffic after the rollout.

## Your mission: Reduce Excess Resource Requests

The `scout` Deployment in `starfleet` has a resource request that does not match its usage. The other workload starts with suitable requests.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-040-02
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-20/labs/lab-02
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-040/module-20/labs/lab-02
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-040-02-02
astrona start ats-020-playground-040-02
```

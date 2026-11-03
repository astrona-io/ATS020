# Find And Fix Over- And Under-Provisioned Workloads

A ratio at one moment is not enough to change a request. The request must cover the highest usage the container reaches, with some room, and it must not be far above it. This part ranks the workloads by their gap over a time range, picks new requests, applies them and proves with a query that the gap closed.

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

The peak memory of `scout` is 35 million bytes (about `34Mi`) and its peak CPU is `0.003` cores (`3m`). A request of `10m` CPU and `64Mi` memory covers that with room. The peak of `probe` is `9Mi` and `3m`. A request of `5m` and `24Mi` covers it. Peaks of a short-lived test are low; on a real workload, read at least a day of history before you choose.

## Apply and prove

The command `kubectl set resources` changes the requests and limits of a Deployment. The Deployment then rolls out new pods with the new values. A memory limit must not be lower than the memory request, so the limit of `scout` changes too:

```sh
kubectl -n starfleet set resources deployment/scout --requests=cpu=10m,memory=64Mi --limits=memory=128Mi
kubectl -n starfleet set resources deployment/probe --requests=cpu=5m,memory=24Mi
kubectl -n starfleet rollout status deployment/scout
kubectl -n starfleet rollout status deployment/probe
```

```text
deployment.apps/scout resource requirements updated
deployment.apps/probe resource requirements updated
deployment "scout" successfully rolled out
deployment "probe" successfully rolled out
```

I shortened the output of the two `rollout status` commands: they print one progress line for every step of the rollout before this last line. Now check the running pods, not only the Deployment. The `RESTARTS` column must stay at `0`:

```sh
kubectl -n starfleet get pods -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIMIT:.spec.containers[0].resources.limits.memory,RESTARTS:.status.containerStatuses[0].restartCount'
```

```text
POD                        CPU_REQ   MEM_REQ   MEM_LIMIT   RESTARTS
probe-64f8957c56-9d96c     5m        24Mi      128Mi       0
scout-5df99d9c5c-7wtfg     10m       64Mi      128Mi       0
scout-5df99d9c5c-x9c24     10m       64Mi      128Mi       0
shuttle-65f695c8c6-6wwmc   10m       16Mi      32Mi        0
```

The proof is a measurement. The next query sums the memory that `scout` and `probe` request. Before the change it was `541065216` bytes, which is 516 mebibytes (`2 * 256Mi + 4Mi`), and the requested CPU was `0.501` cores:

```sh
promql 'sum(kube_pod_container_resource_requests{namespace="starfleet",resource="memory",container=~"scout|probe"})'
promql 'sum(kube_pod_container_resource_requests{namespace="starfleet",resource="cpu",container=~"scout|probe"})'
```

```text
{"metric":{},"value":"159383552"}
{"metric":{},"value":"0.025"}
```

The requested memory fell from 516 to 152 mebibytes (`2 * 64Mi + 24Mi`), and the requested CPU fell from `0.501` to `0.025` cores. The gap of the two workloads also closed. Run the memory ratio query from the start of this part again: after a minute for the new pods to be scraped, `scout` shows `1.9` and `probe` shows `2.7`. Both are above `1`, so no container asks for less than it peaks, and neither is far above it.

You can now rank workloads by the gap between request and peak usage, choose requests with room above the peak and prove the change with the requested totals and the ratios. The remaining risk is a peak that your window did not see. That is why the next review of the numbers belongs in the calendar, not in the memory of the team.

## Common pitfalls

> [!WARNING]
> - **Lowering a request without looking at the peak.** A request below the peak makes the scheduler pack the node too tight, and a memory limit below the peak makes the kubelet stop the container with `OOMKilled`.
> - **Removing requests to "fix" waste.** A pod without requests is scheduled as if it needed nothing, and it is the first one the kubelet evicts under pressure. Size the requests, do not delete them.
> - **A memory limit below the new request.** The API server rejects a pod where the limit is lower than the request.
> - **Sizing to an average.** Use `max_over_time()`, because the request must cover the highest usage, not the usual one.
> - **A window that is too short.** A 30-minute window does not contain the daily peak of a real service. Use days of history.
> - **Checking only the Deployment.** Read the running pods. A rollout that is stuck leaves old pods with the old requests.

## Your mission: Right-Size Two Deployments

You can now compare requests with measured usage and change them with evidence. The mission gives you a cluster where one Deployment requests far more than it uses and another requests less than it uses. Right-size both and keep the service running.

Pause the playground, then start the lab:

```sh
astrona stop ats-020-playground-040-02
```

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-02/labs/lab-02
```

The task is on the next page. When you have changed the Deployments, grade your work:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-02
```

When the lab is done, remove it and start the playground again:

```sh
astrona destroy ats-020-lab-040-02-02
astrona start ats-020-playground-040-02
```

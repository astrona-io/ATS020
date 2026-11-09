# Requests Versus Usage With kubectl top And Prometheus

Kubernetes schedules pods using requests, while metrics report what containers actually consume. Compare both for the same workload and units. Use recent samples to investigate, then a representative history to choose new requests.

## Requests, limits and usage

A resource request is the amount of CPU or memory that a container asks the scheduler to reserve. The scheduler adds up the requests of the pods on a node and refuses to place a pod when the sum would be more than the node can give. A limit is the cap: a container that uses more CPU than its limit is throttled, and a container that uses more memory than its limit is stopped with the status `OOMKilled`. Usage is what the container really consumes at that moment.

Waste is the difference between the request and the usage. A request that is too high wastes capacity. A request that is too low is a risk, because the scheduler packs pods on a node that cannot really carry them. The playground has both cases.

Two systems report usage. metrics-server is a cluster component that reads the usage of every pod from the kubelet every 15 seconds and keeps only the latest value. It serves that value through the Metrics API, and the command `kubectl top` reads that API. Prometheus keeps the history instead, but it needs the kubelet scrape job (cAdvisor) and kube-state-metrics for the requests. Both are installed in the playground.

## kubectl top: the latest usage

Start with the latest usage for each container. The flag `--containers` shows the containers of a pod separately:

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet top pods --containers
```

```text
POD                        NAME      CPU(cores)   MEMORY(bytes)   
probe-5785db494b-d7klv     probe     3m           7Mi             
scout-7d6476c64-chlvv      scout     2m           28Mi            
scout-7d6476c64-p8v6s      scout     3m           30Mi            
shuttle-65f695c8c6-6wwmc   shuttle   13m          6Mi             
```

The unit `m` means millicores: `1000m` is one CPU core. Each `scout` pod uses about 3 millicores of CPU and 30 mebibytes (`Mi`) of memory. If the command prints `error: metrics not available yet`, metrics-server has not scraped the pods yet. Wait 30 seconds and run it again.

Now read what the same pods requested. A `custom-columns` output shows fields of the pod object, so no extra component is involved:

```sh
kubectl -n starfleet get pods -o custom-columns='POD:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory'
```

```text
POD                        CPU_REQ   MEM_REQ
probe-5785db494b-d7klv     1m        4Mi
scout-7d6476c64-chlvv      250m      256Mi
scout-7d6476c64-p8v6s      250m      256Mi
shuttle-65f695c8c6-6wwmc   10m       16Mi
```

Each `scout` pod requests `250m` of CPU and `256Mi` of memory and uses `3m` and `30Mi`. The `probe` pod is the opposite: it requests `4Mi` of memory and uses `7Mi`. The node view shows what the scheduler sees:

```sh
kubectl describe node | grep -A5 "Allocated resources"
kubectl top nodes
```

```text
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                1721m (28%)  0 (0%)
  memory             1374Mi (6%)  1780Mi (7%)
NAME                                            CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
astro-ats-020-playground-040-02-control-plane   93m          1%       1267Mi          5%          
```

The scheduler counts `1721m` of CPU as taken, which is 28 percent of the node. The node really uses `93m`, which is 1 percent. The difference of 27 percent is reserved and idle. On this single node the cost is small, but a real cluster pays for every node.

## Prometheus: usage over time

`kubectl top` shows one moment. It cannot tell you the peak of the last hour, and a request must cover the peak. Prometheus stores the history. The kubelet contains cAdvisor, a component that measures the CPU and memory of every container. Prometheus scrapes it at the path `/metrics/cadvisor`. Two metrics matter:

- `container_cpu_usage_seconds_total` is a counter of the CPU seconds that a container used. Its `rate()` is the number of cores in use.
- `container_memory_working_set_bytes` is a gauge, a value that goes up and down. It is the memory in use that the kernel cannot easily take back. This is the number that `kubectl top` shows and that the kubelet compares with the memory limit.

Open a port-forward to Prometheus and define the helper that runs a query:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 &
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.endpoint, .instance, .job, .service, .namespace)), value: .value[1]}'
}
```

Ask for the CPU cores and the memory bytes of each pod. The selector `container!=""` removes the series that cAdvisor reports for the whole pod, so only real containers remain:

```sh
promql 'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="starfleet",container!=""}[5m]))'
promql 'sum by (pod) (container_memory_working_set_bytes{namespace="starfleet",container!=""})'
```

```text
{"metric":{"pod":"shuttle-65f695c8c6-6wwmc"},"value":"0.013731990577905114"}
{"metric":{"pod":"probe-5785db494b-d7klv"},"value":"0.002061999446805985"}
{"metric":{"pod":"scout-7d6476c64-p8v6s"},"value":"0.002049975580111744"}
{"metric":{"pod":"scout-7d6476c64-chlvv"},"value":"0.0019133336231965288"}
{"metric":{"pod":"shuttle-65f695c8c6-6wwmc"},"value":"7217152"}
{"metric":{"pod":"probe-5785db494b-d7klv"},"value":"7958528"}
{"metric":{"pod":"scout-7d6476c64-p8v6s"},"value":"32202752"}
{"metric":{"pod":"scout-7d6476c64-chlvv"},"value":"32411648"}
```

The first four lines are CPU cores. The `scout` pods use about `0.002` cores, which is `2m`. The last four lines are memory in bytes. A `scout` pod uses about 32 million bytes, which is `31Mi`. The values agree with `kubectl top`, within the small difference that comes from different sample times and windows.

The requests come from kube-state-metrics, a component that reads the objects from the Kubernetes API and exports their fields as metrics. The metric `kube_pod_container_resource_requests` has one series for each container and resource. Divide the requested memory by the used memory for each pod:

```sh
promql 'sum by (pod) (kube_pod_container_resource_requests{namespace="starfleet",resource="memory",container!=""}) / sum by (pod) (container_memory_working_set_bytes{namespace="starfleet",container!=""})'
```

```text
{"metric":{"pod":"shuttle-65f695c8c6-6wwmc"},"value":"2.3246311010215663"}
{"metric":{"pod":"scout-7d6476c64-p8v6s"},"value":"8.335792419231748"}
{"metric":{"pod":"probe-5785db494b-d7klv"},"value":"0.5270200720535255"}
{"metric":{"pod":"scout-7d6476c64-chlvv"},"value":"8.282067483887275"}
```

A ratio above `1` means the request is higher than the usage. Each `scout` pod requests 8 times the memory it uses. A ratio below `1` means the container uses more than it requested. The `probe` pod has a ratio of `0.53`: it uses almost twice the memory it asked for, so the scheduler reserved too little for it.

## Common pitfalls

> [!WARNING]
> - **Reading `kubectl top` as the peak.** It shows the latest value only. A container that peaks every 10 minutes can look idle between peaks.
> - **Using `container_memory_usage_bytes`.** It includes cache that the kernel can take back. Use `container_memory_working_set_bytes`, which is the number the kubelet uses.
> - **Forgetting `container!=""`.** Without it, cAdvisor series for the pod as a whole are counted too, and the totals double.
> - **A counter without `rate()`.** `container_cpu_usage_seconds_total` only grows. Only its `rate()` is a number of cores.
> - **Comparing CPU in cores with millicores.** Prometheus returns cores (`0.25`) while Kubernetes writes `250m`. Convert before you compare.
> - **Expecting `kubectl top` right after a start.** metrics-server needs its first scrape. `metrics not available yet` goes away on its own.

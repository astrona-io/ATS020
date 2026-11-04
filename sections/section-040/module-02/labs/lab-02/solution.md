# Solution

This walkthrough measures the usage of `scout` and `probe`, compares it with their requests, and changes both Deployments. Values in the output differ a little in your cluster.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-040/module-02/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Compare the requests with the usage now

Read the requests of both Deployments:

```sh
kubectl -n starfleet get deploy scout probe -o 'custom-columns=NAME:.metadata.name,CPU_REQ:.spec.template.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.template.spec.containers[0].resources.requests.memory,MEM_LIMIT:.spec.template.spec.containers[0].resources.limits.memory'
```

```text
NAME    CPU_REQ   MEM_REQ   MEM_LIMIT
scout   250m      256Mi     256Mi
probe   1m        2Mi       128Mi
```

Read what the pods use right now. metrics-server answers this command:

```sh
kubectl -n starfleet top pod
```

```text
NAME                       CPU(cores)   MEMORY(bytes)
scout-7d6476c64-c87w5      2m           19Mi
scout-7d6476c64-w9nw2      3m           20Mi
shuttle-65f695c8c6-nqntb   13m          0Mi
```

Each `scout` pod uses 2 to 3 millicores of CPU and about 20Mi of memory. It requests 250m and 256Mi. The output lists no row for `probe`, because metrics-server had no sample for the new `probe` pod yet. Run the command again after a minute, or use Prometheus in the next step.

## Step 2: Find the peak usage in Prometheus

The request must cover the highest usage, not the usual one. Open a port-forward and define a helper that runs a query:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 &
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | [.metric.container, .value[1]]'
}
```

Read the peak memory of each container over the last hour:

```sh
promql 'max by (container) (max_over_time(container_memory_working_set_bytes{namespace="starfleet",container=~"scout|probe"}[1h]))'
```

```text
["probe","6426624"]
["scout","22470656"]
```

`scout` peaks at about 21Mi, and `probe` at about 6Mi. `probe` requests only 2Mi, so it uses three times its request. Read the peak CPU the same way. The subquery `[1h:30s]` takes the highest 2-minute rate in the last hour:

```sh
promql 'max by (container) (max_over_time(rate(container_cpu_usage_seconds_total{namespace="starfleet",container=~"scout|probe"}[2m])[1h:30s]))'
```

```text
["probe","0.0008326692854574578"]
["scout","0.0009651583091933532"]
```

Both containers peak at about 1 millicore (`0.001` cores). `scout` requests 250 millicores. The node view shows the cost of that gap:

```sh
kubectl describe node | sed -n '/Allocated resources/,/ephemeral/p'
```

```text
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                1721m (28%)  0 (0%)
  memory             1372Mi (6%)  1780Mi (7%)
  ephemeral-storage  0 (0%)       0 (0%)
```

## Step 3: Change the requests

Choose values from the peaks. For `scout`, ask for `64Mi` of memory, which is about three times the peak, and `10m` of CPU, which is ten times the peak and still a small share of a core. Keep a memory limit of `128Mi`. A memory limit is not lower than the request, so the API server accepts it. For `probe`, ask for `24Mi` of memory, four times the peak, and `5m` of CPU.

`kubectl set resources` changes both requests and limits in one command and starts a rollout:

```sh
kubectl -n starfleet set resources deployment/scout --requests=cpu=10m,memory=64Mi --limits=memory=128Mi
kubectl -n starfleet set resources deployment/probe --requests=cpu=5m,memory=24Mi
```

```text
deployment.apps/scout resource requirements updated
deployment.apps/probe resource requirements updated
```

Wait for both rollouts to finish:

```sh
kubectl -n starfleet rollout status deployment/scout
kubectl -n starfleet rollout status deployment/probe
```

```text
deployment "scout" successfully rolled out
deployment "probe" successfully rolled out
```

(The command prints one "Waiting for deployment" line for each step of the rollout before this last line. They are left out here.)

## Step 4: Prove the change on the running pods

Read the requests of the running pods, not only of the Deployments. The old `scout` pods can stay in the list for a few seconds while they terminate:

```sh
kubectl -n starfleet get pods -l 'app in (scout,probe)' -o 'custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[0].resources.requests.cpu,MEM_REQ:.spec.containers[0].resources.requests.memory,MEM_LIMIT:.spec.containers[0].resources.limits.memory'
```

```text
NAME                     CPU_REQ   MEM_REQ   MEM_LIMIT
probe-64f8957c56-xd6t6   5m        24Mi      128Mi
scout-5df99d9c5c-qn9ng   10m       64Mi      128Mi
scout-5df99d9c5c-sd254   10m       64Mi      128Mi
scout-7d6476c64-c87w5    250m      256Mi     256Mi
scout-7d6476c64-w9nw2    250m      256Mi     256Mi
```

The last two rows are the old pods. They are `Terminating` and disappear. The node view now shows the reserved CPU and memory going down:

```text
  cpu                1245m (20%)  0 (0%)
  memory             1010Mi (4%)  1524Mi (6%)
```

The watch terminal now shows all three checks passing. Press Ctrl-C to stop the watch, then submit once:

```sh
astrona submit -c sections/section-040/module-02/labs/lab-02
```

## Why the plausible shortcuts fail

- **Deleting the requests and limits.** The first two checks need a CPU request, a memory request and a memory limit on the running pods.
- **Leaving `scout` at `256Mi` and `250m`.** The first check rejects a memory request above four times the peak (or `100Mi`) and a CPU request above four times the peak (or `20m`).
- **Leaving `probe` at `2Mi`.** The second check needs a memory request at or above the measured peak.
- **Setting tiny requests for both.** The checks reject a memory request below the peak.
- **Removing the memory limit instead of sizing it.** Both checks need a memory limit that is not below the request or the peak.
- **Scaling `scout` down to one replica to save resources.** The third check needs 2 ready `scout` replicas and 1 ready `probe` replica.

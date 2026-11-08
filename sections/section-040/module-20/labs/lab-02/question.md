# Question

Solve this question on: `terminal`

The platform team reviews the resource requests of the workloads in the namespace `starfleet`. The scheduler reserves the requested CPU and memory on the node, whether the workload uses it or not. The review found two problems. The Deployment `scout` has 2 replicas and requests far more CPU and memory than it uses, so it wastes capacity. The Deployment `probe` requests less memory than it uses, so it is easy to evict when the node runs short of memory.

A traffic loop keeps both workloads busy. Prometheus stores their real usage. The team asks you to right-size both Deployments without breaking the service.

## Task

1. Measure the real usage of `scout` and `probe`. Compare it with what each Deployment requests. Use `kubectl top pod`, `kubectl describe node` or Prometheus (`container_memory_working_set_bytes`, `container_cpu_usage_seconds_total` and `kube_pod_container_resource_requests`).
2. Change the Deployment `scout` so that its memory and CPU requests are close to its measured peak usage.
3. Change the Deployment `probe` so that its memory request covers its measured peak usage.
4. Prove the change. The running pods must show the new requests, and every pod must be ready.

## Constraints

- Work on the container `scout` in the Deployment `scout` and on the container `probe` in the Deployment `probe`, both in the namespace `starfleet`.
- Size from the measured peak, not from the average. A request must not be below the peak memory usage.
- Do not set a request far above the peak. The upper limit is four times the peak memory usage (or `100Mi`, whichever is higher) and four times the peak CPU usage (or `20m`, whichever is higher).
- Keep a memory limit on both containers. The limit must not be below the request or the peak.
- Do not change the number of replicas. `scout` keeps 2 and `probe` keeps 1.
- Do not delete a Deployment, and do not remove the traffic loop. No pod may restart or be killed for lack of memory.

## How the answer is checked

The grader runs three checks. The first reads the running `scout` pods and compares their CPU and memory requests with the peak usage that Prometheus measured over the last hour. The second does the same for the running `probe` pod. The third checks that `scout` has 2 ready replicas, `probe` has 1, and a request from `shuttle` to `scout` returns `200`. The grader reads the pods, not only the Deployments, so wait for the rollout to finish before you submit.

Hint: reach Prometheus with `kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090`.

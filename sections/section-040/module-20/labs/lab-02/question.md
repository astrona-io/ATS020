# Question

Solve this question on: `terminal`

The `scout` Deployment in `starfleet` has a resource request that does not match its usage. The other workload starts with suitable requests.

## Tasks

1. Measure the peak CPU and memory usage of `scout` in Prometheus.
2. Compare the measured peak with the requests and memory limit on its running Pods.
3. Adjust only `scout` to cover measured usage without reserving excessive resources.
4. Wait for the rollout; verify unchanged replica counts, ready Pods without restarts, and a successful request from `shuttle`.

## Constraints

- Keep `scout` at two replicas and `probe` at one.
- Keep the traffic loop and memory limits.
- Memory requests must cover the measured peak and be no higher than four times the peak or `100Mi`, whichever is larger.
- CPU requests must be positive and no higher than four times the peak or `20m`, whichever is larger.
- Limits must cover requests and peak usage.

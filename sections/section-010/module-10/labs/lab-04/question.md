# Question

Solve this question on: `terminal`

The `scout` Pods in `outpost` expose metrics without a Service. Prometheus does not yet scrape them.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Inspect Pod labels and named container ports.
2. Create `outpost/scout` as a PodMonitor selected by Prometheus.
3. Wait for the Operator to load the generated scrape job.
4. Verify one healthy `podMonitor/outpost/scout/0` target for every ready `scout` Pod.

## Constraints

Do not create a Service or change the Pods. Keep the Prometheus resource selectors. Use `release: kps`, the `app: scout` Pod selector and container port `http`.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

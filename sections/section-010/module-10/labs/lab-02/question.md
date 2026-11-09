# Question

Solve this question on: `terminal`

Plain Prometheus discovers only `telemetry: primary` Pods. The `reserve` workload is missing from the `starfleet-pods` job.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Read the active Pod discovery job and compare workload labels.
2. Extend its keep rule to include `primary` and `reserve` Pods. Keep disabled Pods excluded.
3. Reload or restart Prometheus to load the configuration.
4. Verify one healthy target per ready selected Pod, with the live address and `namespace`, `pod` and `deployment` labels.

## Constraints

Keep discovery dynamic with `role: pod`, the ready-Pod and named-port filters, and its existing labels. Keep workload images, labels and metric values unchanged. Do not install an Operator.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

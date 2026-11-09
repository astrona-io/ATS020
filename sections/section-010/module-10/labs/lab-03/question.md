# Question

Solve this question on: `terminal`

Both metric workloads are already scraped. Use their queue gauges to decide which Deployment needs more replicas.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Confirm that the primary and reserve Pods are healthy scrape targets.
2. Query the sum of `starfleet_queue_items` by Deployment and identify the highest total.
3. Scale only that Deployment to three replicas.
4. Verify three ready replicas and newly discovered targets, while the other two Deployments keep one ready replica each.

## Constraints

Keep discovery dynamic with `role: pod`, the ready-Pod and named-port filters, and its existing labels. Keep workload images, labels and metric values unchanged. Do not install an Operator.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

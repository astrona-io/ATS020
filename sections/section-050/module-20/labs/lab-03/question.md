# Question

Solve this question on: `terminal`

Prometheus runs, but it does not scrape `scout` or load `ScoutDown`. The Prometheus Operator Deployment `kps-operator` in `monitoring` has stopped.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Inspect the operator Deployment and its replica counts.
2. Confirm that the ServiceMonitor `scout` and PrometheusRule `scout-alerts` exist in `starfleet`.
3. Restore the operator to one ready replica.
4. Verify `up{job="scout"}` is `1` and the `ScoutDown` rule is loaded in Prometheus.

## Constraints

Keep the existing operator, Prometheus, workload, monitor and rule. Do not install a second monitoring stack.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

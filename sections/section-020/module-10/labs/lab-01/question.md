# Question

Solve this question on: `terminal`

The team stores `Scout Overview` (UID `scout-overview`) in `monitoring/dashboard-scout-overview`. Grafana uses the provisioned Prometheus data source (UID `prometheus`).

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Find the dashboard ConfigMap and inspect the sidecar label selector.
2. Add the label that makes the sidecar copy this dashboard.
3. Wait for Grafana to load `scout-overview` as a provisioned dashboard.
4. Confirm the dashboard keeps three panels and returns data for `starfleet`.

## Constraints

Keep all three panels and their queries. Keep the dashboard and data source provisioned from ConfigMaps. Do not save the dashboard in the Grafana database or create a second data source.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

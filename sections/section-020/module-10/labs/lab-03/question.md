# Question

Solve this question on: `terminal`

The team stores `Scout Overview` (UID `scout-overview`) in `monitoring/dashboard-scout-overview`. Grafana uses the provisioned Prometheus data source (UID `prometheus`).

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Inspect the provisioned Prometheus data source UID and the dashboard JSON.
2. Correct the data source references in all three panels.
3. Correct the namespace variable to use the same data source.
4. Confirm every panel returns data with the namespace set to `starfleet`.

## Constraints

Keep all three panels and their queries. Keep the dashboard and data source provisioned from ConfigMaps. Do not save the dashboard in the Grafana database or create a second data source.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

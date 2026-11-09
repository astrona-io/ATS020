# Question

Solve this question on: `terminal`

Loki stores logs with `namespace`, `pod` and `container` labels. Grafana has the editable `loki` data source and the saved `outpost-logs` dashboard.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Open the editable Loki data source and set Maximum lines to `250`.
2. Set the Error lines panel to show only `outpost` lines containing uppercase `ERROR`.
3. Set Streams with errors to `count(rate({namespace="outpost"} |= "ERROR" [5m]))` and save the dashboard.
4. Run both queries and confirm the saved dashboard uses the `loki` data source.

## Constraints

An error contains the exact uppercase text `ERROR`; lower-case `error` does not match. Keep all controllers. Do not change workloads in `starfleet`. Keep the data source URL and editable dashboard.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

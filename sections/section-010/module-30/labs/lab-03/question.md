# Question

Solve this question on: `terminal`

`ProbeMaintenance` fires in Prometheus and has reached Alertmanager. Suppress its notifications during a planned maintenance window.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Find the maintenance alert and read its labels.
2. Create a silence with the exact matchers, duration and author below.
3. Verify that Alertmanager marks the matching alert as suppressed.
4. Confirm that `ProbeMaintenance` remains firing in Prometheus and `ScoutErrorRate` is not silenced.

## Constraints

Use exactly two equality matchers: `alertname="ProbeMaintenance"` and `namespace="starfleet"`. Set duration to `30m`, author to `platform`, and comment to `probe maintenance window`. Keep both alerting rules and the routing configuration.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

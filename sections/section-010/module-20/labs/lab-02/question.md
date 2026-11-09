# Question

Solve this question on: `terminal`

The recording rule `scout:error_ratio:rate5m` in `monitoring/scout-queries` returns the wrong result. The other recording rule is already correct.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Query `scout:error_ratio:rate5m` and inspect its expression.
2. Compare the source metric and labels with the traffic sent to `scout` in `starfleet`.
3. Repair only the assigned expression using a five-minute window.
4. Confirm that `scout:error_ratio:rate5m` returns exactly one series matching the measured traffic.

## Constraints

Keep both recording rules, their names and the `release: kps` label. Use the real metrics; do not substitute constants with `vector()` or `scalar()`. Keep the other rule unchanged.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

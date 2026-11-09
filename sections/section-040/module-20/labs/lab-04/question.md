# Question

Solve this question on: `terminal`

Traffic to `scout` includes HTTP 500 responses. Create recording rules that measure availability and the remaining budget for a 99% objective.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Inspect the request counter and confirm the status labels that represent failed requests.
2. Create `scout-sli` in `monitoring`, selected by `release: kps`, with good-request ratios over five minutes and one hour.
3. Record the one-hour remaining budget as `1 - (1 - SLI) / (1 - 0.99)`.
4. Query all three series and explain the meaning of a negative remaining budget.

## Constraints

Use record names `scout:sli:ratio_rate5m`, `scout:sli:ratio_rate1h` and `scout:error_budget_remaining:ratio1h`. Aggregate scout request rates across pods. Keep traffic and the workload unchanged. A fresh cluster contains less than an hour of samples.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

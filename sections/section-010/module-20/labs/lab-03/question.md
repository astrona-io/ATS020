# Question

Solve this question on: `terminal`

The recording rule `scout:request_duration_seconds:p95_5m` in `monitoring/scout-queries` returns the wrong result. The other recording rule is already correct.

## Tasks

1. Query `scout:request_duration_seconds:p95_5m` and inspect its expression.
2. Compare the source metric and labels with the traffic sent to `scout` in `starfleet`.
3. Repair only the assigned expression using a five-minute window.
4. Confirm that `scout:request_duration_seconds:p95_5m` returns exactly one series matching the measured traffic.

## Constraints

- Keep both recording rules, their names and the `release: kps` label.
- Use the real metrics; do not substitute constants with `vector()` or `scalar()`.
- Keep the other rule unchanged.

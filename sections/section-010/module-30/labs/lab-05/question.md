# Question

Solve this question on: `terminal`

Two warning alerts differ by Pod. A route stops after the first matching child and groups each Pod separately, so the archive receiver is skipped and notifications are split.

## Tasks

1. Read the two `ScoutRouteCheck` alerts and predict which child routes match.
2. Make the warning route continue to the archive route.
3. Group each receiver's notifications by `namespace` and `alertname`, excluding `pod`.
4. Verify both alerts reach both receivers and appear together in one group per receiver.

## Constraints

- Keep the default, warning and archive receivers with their existing webhook URL.
- Keep both diagnostic alerts.
- Each alert must reach warning and archive, with no default receiver.
- Preserve the timing fields.

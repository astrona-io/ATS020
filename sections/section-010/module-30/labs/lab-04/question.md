# Question

Solve this question on: `terminal`

Two diagnostic alerts fire: `ScoutUnavailable` is critical and `ScoutLatency` is warning. The team wants the critical alert to suppress the related warning automatically.

## Tasks

1. Read both firing diagnostic alerts and their labels.
2. Compare the inhibition source matchers with the critical alert.
3. Repair the source matcher while keeping the warning target and equal labels.
4. Verify the warning is inhibited by the critical alert, with no silence, while both still fire in Prometheus.

## Constraints

- Keep both diagnostic rules and the existing route.
- Match the critical source and warning target by `team=scout-inhibit`, and require equal `namespace` and `team`.
- Do not create a silence or remove an alert.

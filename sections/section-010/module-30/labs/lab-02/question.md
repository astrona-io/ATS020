# Question

Solve this question on: `terminal`

`ScoutErrorRate` is already installed. The AlertmanagerConfig `starfleet/scout-routing` matches the wrong team, so the webhook receives no notification.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Confirm that `ScoutErrorRate` fires in Prometheus.
2. Inspect the labels on the alert and the matchers in `scout-routing`.
3. Repair the route to deliver `team="scout"` alerts to `scout-webhook`.
4. Verify the active receiver in Alertmanager and a firing notification in the receiver log.

## Constraints

Keep the existing alert and webhook URL `http://alert-receiver.monitoring:8080/`. The receiver must be `starfleet/scout-routing/scout-webhook`. Do not silence the team alert.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

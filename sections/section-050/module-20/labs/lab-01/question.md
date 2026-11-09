# Question

Solve this question on: `terminal`

The `starfleet-policy` admission webhook blocks Deployment creation in `starfleet`. Its server and Service run in `webhook-system`.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Attempt a Deployment create and read the webhook connection error.
2. Compare the Service target port with the server listening port.
3. Repair the Service without weakening the webhook.
4. Create a Deployment successfully, confirm a new admission request in the server log, and delete your test Deployment.

## Constraints

Keep the webhook configuration, its namespace selector, Deployment rules, Service and `failurePolicy: Fail`. Keep the trusted CA unchanged. Do not bypass admission.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

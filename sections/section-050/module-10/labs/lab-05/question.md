# Question

Solve this question on: `terminal`

The `beacon` image exists, but its process exits during startup. The Service and `shuttle` client are healthy.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Read the current and previous container logs.
2. Compare the command override with the image's normal startup.
3. Remove the invalid override and let the image start its server.
4. Verify a ready replacement pod and HTTP status `200` from `shuttle`.

## Constraints

Keep the image, one replica, Service and resource settings. Do not replace the server with a sleeping container.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

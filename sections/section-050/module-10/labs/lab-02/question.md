# Question

Solve this question on: `terminal`

The `probe` Deployment in `starfleet` is unhealthy. The `shuttle` client and the Service `probe` are available for testing.

## Tasks

1. Inspect the pod events and its liveness probe port and container port. Identify the cause of the failure.
2. Repair the liveness probe so it tests the HTTP server on its listening port.
3. Wait for the replacement `probe` pod to become ready. Check its restart count.
4. Send a request from `shuttle` to `http://probe:8080/` and confirm HTTP status `200`.

## Constraints

- Keep `probe`, its Service and `shuttle`, with one replica each.
- Keep a liveness probe.
- Do not disable health checks or change the image.

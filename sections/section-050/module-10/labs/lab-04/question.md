# Question

Solve this question on: `terminal`

The `beacon` Deployment in `starfleet` is unhealthy. The `shuttle` client and the Service `beacon` are available for testing.

## Tasks

1. Inspect the pod events and its image reference and image pull events. Identify the cause of the failure.
2. Use the image `ghcr.io/stefanprodan/podinfo:6.17.0`.
3. Wait for the replacement `beacon` pod to become ready. Check its restart count.
4. Send a request from `shuttle` to `http://beacon:9898/` and confirm HTTP status `200`.

## Constraints

- Keep `beacon`, its Service and `shuttle`, with one replica each.
- Keep the existing command, arguments and resources.

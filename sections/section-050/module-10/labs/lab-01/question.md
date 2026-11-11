# Question

Solve this question on: `terminal`

The `scout` Deployment in `starfleet` is unhealthy. The `shuttle` client and the Service `scout` are available for testing.

## Tasks

1. Inspect the pod events and its node selector and node labels. Identify the cause of the failure.
2. Change the scheduling constraint so an existing node can run the pod.
3. Wait for the replacement `scout` pod to become ready. Check its restart count.
4. Send a request from `shuttle` to `http://scout:9898/` and confirm HTTP status `200`.

## Constraints

- Keep `scout`, its Service and `shuttle`, with one replica each.
- Keep the original image and resource settings.

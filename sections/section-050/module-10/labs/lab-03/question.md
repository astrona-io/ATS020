# Question

Solve this question on: `terminal`

The `cargo` Deployment in `starfleet` is unhealthy. The `shuttle` client and the Service `cargo` are available for testing.

## Tasks

1. Inspect the pod events and its last termination reason and memory limit. Identify the cause of the failure.
2. Set a memory limit that lets the existing process run.
3. Wait for the replacement `cargo` pod to become ready. Check its restart count.
4. Send a request from `shuttle` to `http://cargo:8080/` and confirm HTTP status `200`.

## Constraints

- Keep `cargo`, its Service and `shuttle`, with one replica each.
- Keep the command and a memory limit of at least `256Mi` and below `1Gi`.

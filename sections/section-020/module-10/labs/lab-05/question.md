# Question

Solve this question on: `terminal`

Grafana was moved to `telemetry`. One startup fault remains; the other settings already allow it to run. The Service `grafana` listens on port `3000`.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Inspect the pod and its last termination reason and the memory limit.
2. Set a memory request and a limit of at least `256Mi` that allow Grafana to start.
3. Wait for one ready Grafana replica and a healthy database response.
4. Sign in as `admin` with password `starfleet` and confirm HTTP status `200`.

## Constraints

Keep the image, command, arguments, environment variable names and Secret key references, probes, Service and provisioning mount unchanged. Keep a volume at `/var/lib/grafana` and a memory limit. Change only the faulty setting named in the tasks.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

# Question

Solve this question on: `terminal`

Grafana was moved to `telemetry`. One startup fault remains; the other settings already allow it to run. The Service `grafana` listens on port `3000`.

## Tasks

1. Inspect the pod and its Secret key reference and the keys present in each namespace.
2. Add the `admin-password` Secret key with value `starfleet`.
3. Wait for one ready Grafana replica and a healthy database response.
4. Sign in as `admin` with password `starfleet` and confirm HTTP status `200`.

## Constraints

- Keep the image, command, arguments, environment variable names and Secret key references, probes, Service and provisioning mount unchanged.
- Keep a volume at `/var/lib/grafana` and a memory limit.
- Change only the faulty setting named in the tasks.

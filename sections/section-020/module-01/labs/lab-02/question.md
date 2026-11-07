---
estimated_duration: 25m
---

# Question

Solve this question on: `terminal`

## Scenario

The platform team moved Grafana from the namespace `monitoring` to the new namespace `telemetry`. Since the move, Grafana does not start. The Deployment `grafana` in `telemetry` has one replica and its Pod never becomes ready. The Service `grafana` in `telemetry` listens on port `3000`. The dashboard team signs in as the user `admin` with the password `starfleet`.

The old Secret `grafana-admin` is still in `monitoring`. The move copied the Deployment, the data source ConfigMap `grafana-datasources` and a new Secret `grafana-admin` into `telemetry`.

## Tasks

1. **Find out why the Pod does not start.** Read the Pod's status, its events and its logs. More than one fault stops it, and the next one only shows after you fix the one before it.
2. **Bring Grafana back.** Change the Deployment and the Secret in `telemetry` until the Deployment has `1` ready replica, `GET /api/health` on the Service reports `"database": "ok"`, and the user `admin` signs in with the password `starfleet`.

## Constraints

You may change only these things:

* the container's resource requests and limits,
* Secrets in the namespace `telemetry`,
* the Deployment's `volumes` and `volumeMounts`.

Do not change the image, the command, the arguments, the names of the environment variables, the probes or the Service. Keep the data source mount at `/etc/grafana/provisioning/datasources`. Keep a volume mounted at `/var/lib/grafana`. Do not delete the Deployment and do not move Grafana back to `monitoring`.

The grader reads the Deployment, the Secret and the Service, calls `/api/health` through the API server proxy, and signs in through a port-forward with HTTP basic authentication.

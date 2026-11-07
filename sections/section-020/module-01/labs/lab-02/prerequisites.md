# Prerequisites

Allow 25 minutes. Be able to read a Pod's status and events with
`kubectl get` and `kubectl describe`, read container logs with `kubectl logs`,
and change a Deployment with `kubectl edit`, `kubectl patch` or
`kubectl set resources`. Know what a Secret key, a volume, a volumeMount and
a memory limit are.

The terminal has kubectl, curl and jq. Grafana is the Deployment and Service
`grafana` in the namespace `telemetry` on port `3000`, with the user `admin`
and the password `starfleet`. The cluster is a single-node `kind` cluster
running Kubernetes 1.35.

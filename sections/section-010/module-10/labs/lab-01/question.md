# Question

Solve this question on: `terminal`

The `scout` workload in the namespace `starfleet` runs two pods behind the Service `scout`. The Service has the label `app: scout` and one port named `http`. The pods serve Prometheus metrics on the path `/metrics`.

The platform team applied the ServiceMonitor `scout` in the namespace `starfleet` so that Prometheus scrapes it. Prometheus shows no `scout` target and no `up` series for it. The Prometheus Operator and Prometheus run in the namespace `monitoring`. Prometheus is the Service `kps-prometheus` on port `9090`.

## Tasks

1. Find out why Prometheus shows no `scout` target. Compare the ServiceMonitor with the labels the Prometheus resource `kps-prometheus` selects, and with the Service `scout`.
2. Fix the ServiceMonitor `scout` until Prometheus scrapes both `scout` pods. More than one field is wrong.
3. Prove the fix. The query `up{job="scout",namespace="starfleet"}` must return one series for each `scout` pod, and each value must be `1`.

## Constraints

- Keep the ServiceMonitor `scout` in the namespace `starfleet`.
- Do not change the Prometheus resource `kps-prometheus`.
- Do not change the Service `scout` or the Deployment `scout`.

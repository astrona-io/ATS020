# Question

Solve this question on: `terminal`

The `scout` workload in the namespace `starfleet` runs two pods behind the Service `scout`. The Service has the label `app: scout` and one port named `http`. The pods serve Prometheus metrics on the path `/metrics`.

The platform team applied the ServiceMonitor `scout` in the namespace `starfleet` so that Prometheus scrapes it. Prometheus shows no `scout` target and no `up` series for it. The Prometheus Operator and Prometheus run in the namespace `monitoring`. Prometheus is the Service `kps-prometheus` on port `9090`.

Allow 10–15 minutes for task work. Cluster startup and telemetry collection add time.

## Tasks

1. Find out why Prometheus shows no `scout` target. Compare the ServiceMonitor with the labels the Prometheus resource `kps-prometheus` selects, and with the Service `scout`.
2. Fix the ServiceMonitor `scout` until Prometheus scrapes both `scout` pods. More than one field is wrong.
3. Prove the fix. The query `up{job="scout",namespace="starfleet"}` must return one series for each `scout` pod, and each value must be `1`.

## Constraints

- Keep the ServiceMonitor `scout` in the namespace `starfleet`.
- Do not change the Prometheus resource `kps-prometheus`.
- Do not change the Service `scout` or the Deployment `scout`.

## How the answer is checked

The grader runs two checks. The first checks that the ServiceMonitor `scout` has the label the Prometheus resource selects, and that the Prometheus resource and the Service are unchanged. The second asks Prometheus for the targets of the ServiceMonitor `scout` and needs one healthy target for each ready `scout` endpoint, with `up` equal to `1`. A changed monitor reaches Prometheus after about a minute, so the grader retries for a few minutes.

Hint: reach Prometheus with `kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090`.

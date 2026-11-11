# Question

Solve this question on: `terminal`

The platform team measures the delivery of the workload `scout` with DORA (DevOps Research and Assessment) metrics. Argo CD, a GitOps controller, deploys `scout` into the namespace `starfleet` from the Application `scout` in the namespace `argocd`. Prometheus scrapes the Argo CD application controller. It has already deployed `scout` ten times, and two of those deployments used an image tag that does not exist.

The team stores three recording rules in the PrometheusRule `dora-scout` in the namespace `monitoring`. The rule `dora:deployments:increase6h` counts deployments and is correct. The rule `dora:change_failure_rate:ratio6h` divides the failed deployments by the deployments. Prometheus returns `0` for the change failure rate, although two deployments failed. The team asks you to fix it.

## Tasks

1. Find out why `dora:change_failure_rate:ratio6h` is `0`. Read the three rules in the PrometheusRule `dora-scout` and query the metrics `argocd_app_sync_total` and `argocd_app_info` in Prometheus.
2. Change the rule `dora:failed_deployments:count6h` so that it counts the deployments that made the Application `Degraded`.
3. Prove the fix. Prometheus must return the real change failure rate for `dora:change_failure_rate:ratio6h`.

## Constraints

- Keep the PrometheusRule `dora-scout` in the namespace `monitoring`, with the label `release: kps`.
- Keep all three recording rules and their names.
- Do not change the rule `dora:deployments:increase6h`.
- Do not type a number into the expression. The count must come from the metrics.
- Do not delete the PrometheusRule or any of its rules.

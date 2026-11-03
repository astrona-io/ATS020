# Question

Solve this question on: `terminal`

The Argo CD Application `scout` deploys the workload `scout` in the namespace `starfleet` from a Git repository in Gitea. The Application has ten recorded deployments. Two of them used an image tag that does not exist, and the Application turned `Degraded` each time. The pod `shuttle` sends steady traffic to `scout`, and about 5% of the requests fail with status `500`. The Deployment `beacon` in `starfleet` has requests far above its real usage. Prometheus is the Service `kps-prometheus` on port `9090` in the namespace `monitoring`. It reads PrometheusRules that have the label `release: kps`.

## Task

1. Record the number of `scout` deployments in the last 6 hours as `dora:deployments:increase6h`. Use the Argo CD sync counter.
2. Record the change failure rate over 6 hours as `dora:change_failure_rate:ratio6h`. Count a failed deployment when the Application turns `Degraded`, and divide by the deployments from step 1.
3. Record the 5xx error ratio of `scout` over 1 hour as `scout:error_ratio:rate1h`, and the remaining error budget of a 99% SLO over that window as `scout:error_budget_remaining:ratio1h`.
4. Create the alert `ScoutErrorBudgetBurn`. It must fire when the error budget burns more than twice as fast as the SLO allows, in both a 5 minute window and a 1 hour window. Record the 5 minute error ratio as `scout:error_ratio:rate5m`.
5. Right-size the Deployment `beacon` in `starfleet`. Set its memory request and CPU request to a little above its real usage, and keep a memory limit above the request.

## Constraints

- Put every rule in a PrometheusRule in the namespace `monitoring` with the label `release: kps`.
- Do not change the Prometheus resource, the Argo CD Application, the Gitea repository or the Deployments `scout` and `shuttle`.
- Do not write a fixed number in place of a calculation, and do not count syncs with the phase `Failed` or `Error`.
- Keep `scout` available with its three replicas, and keep one healthy replica of `beacon`.

## How the answer is checked

The grader reads Prometheus. It needs the deployment count between 8 and 11, the change failure rate between 0.15 and 0.30 from the `Degraded` health status, a negative remaining budget that matches the ratio calculated from `http_requests_total`, and the alert loaded with both windows, a non-zero threshold and `for` of at most 5 minutes, in the state `firing`. It reads the requests of `beacon` and checks that they are above usage but within a small margin, and that the Application and the other workloads are unchanged. A new rule reaches Prometheus after about a minute, so the grader retries for several minutes.

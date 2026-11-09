# Question

Solve this question on: `terminal`

A release went out and the namespace `starfleet` is down. Three workloads are unhealthy: `probe`, `cargo` and `beacon`. Each has a Deployment and a Service of the same name. The `shuttle` pod is healthy and sends test requests with `kubectl exec deploy/shuttle -- curl ...`. The release pipeline also cannot create new Deployments in `starfleet`: every create fails with an error about a webhook.

The four faults are independent and none of them shows its cause in the `STATUS` column. Find each cause, fix it, and prove the recovery.

## Task

1. Find out why each of the three workloads is not serving, and write down the cause of each in one line.
2. Fix each workload so that its pod is `Ready` and does not restart.
3. Find out why a create of a Deployment in `starfleet` fails, and fix the cause so that the create works and the webhook server `starfleet-policy` answers the request.
4. Prove the recovery with a request from `shuttle` that returns HTTP status `200` for each Service:
   - `probe` on port `8080`
   - `cargo` on port `8080`
   - `beacon` on port `9898`

## Constraints

- Keep the three Deployments, their Services and their names. Do not delete a Deployment and do not scale one to zero. Each keeps one replica.
- `beacon` must use the existing image tag `ghcr.io/stefanprodan/podinfo:6.17.0`, not `latest`.
- Do not remove the liveness probe of `probe`. Make it check a port and path the server really serves.
- Do not remove the memory limit of `cargo`. Size it to what the process really uses, and keep it below `1Gi`. Do not change the command of `cargo`.
- Keep the `ValidatingWebhookConfiguration` `starfleet-policy` with `failurePolicy: Fail`. Do not delete it and do not set `failurePolicy: Ignore`. Fix the Service behind it, which is in the namespace `webhook-system`.
- Do not change `shuttle`.

## How the answer is checked

The grader runs five checks. Three check one workload each: a `Ready` pod, no restarts, the rules above for that workload, and a `200` from `shuttle`. The fourth creates a real Deployment in `starfleet` and checks that the webhook server logged a new request, so a bypass does not pass. The fifth checks that the workloads, their Services, the webhook configuration, the webhook server and `shuttle` are still in place. The grader waits and retries for a few minutes, because pods and endpoints update late.

Hint: start with `kubectl -n starfleet get pods`, then read the last state and the events of each broken pod. For the webhook, read the error text of a failing create: it names the Service. A memory limit that is too low leaves no error in the log.

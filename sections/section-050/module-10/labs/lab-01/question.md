# Question

Solve this question on: `terminal`

The namespace `starfleet` runs four workloads, each with a Deployment and a Service of the same name: `scout`, `probe`, `cargo` and `beacon`. A deploy went out and all four are unhealthy. The `shuttle` pod is healthy and sends test requests with `kubectl exec deploy/shuttle -- curl ...`.

The four workloads fail in four different ways. The status column of `kubectl get pods` does not tell you the cause. You must find each cause and fix it.

## Task

1. Find out why each of the four workloads is not serving, and write down the cause of each in one line.
2. Fix each workload so that its pod is `Ready` and does not restart.
3. Prove each fix with a request from `shuttle` to the Service that returns HTTP status `200`:
   - `scout` on port `9898`
   - `probe` on port `8080`
   - `cargo` on port `8080`
   - `beacon` on port `9898`

## Constraints

- Keep the four Deployments, their Services and their names. Do not delete a Deployment and do not scale one to zero. Each keeps one replica.
- `scout` and `beacon` run the image `ghcr.io/stefanprodan/podinfo:6.17.0`. `beacon` must use this exact existing tag, not `latest`.
- Do not remove the liveness probe of `probe`. Make it check something the server really serves.
- Do not remove the memory limit of `cargo`. Size it to what the process really uses, and keep it below `1Gi`. Do not change the command of `cargo`.
- Do not change `shuttle`.

## How the answer is checked

The grader runs five checks. The first four check one workload each: a `Ready` pod, no restarts, the rules above for that workload, and a `200` from `shuttle`. The fifth checks that all four Deployments, their Services and `shuttle` are still in place with one replica each. The grader waits and retries for a few minutes, because pods start late.

Hint: start with `kubectl -n starfleet get pods`, then read the events of each broken pod. Events and the last state of the container name the cause. A memory limit that is too low leaves no error in the log.

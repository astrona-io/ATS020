# Overview: Triage And Fix Failing Workloads (Playground)

This playground gives you a cluster in which six workloads in the namespace `starfleet` are broken on purpose. Each one fails in a different way. You find the cause of each failure with `kubectl`, fix it, and prove the fix with a request from `shuttle` or with the state of the pod. There is no grading.

## What's in the box

The cluster runs Kubernetes 1.35.8 on one node. The metrics-server add-on is installed, so `kubectl top` works. No Prometheus, no Grafana and no other monitoring stack runs. The bootstrap changes no workload: every fault is still there when you get the terminal.

| Workload | Image | What is wrong |
| --- | --- | --- |
| `shuttle` | `curlimages/curl:8.22.0` | Nothing. It is a healthy client pod that you use to send requests with `kubectl exec deploy/shuttle -- curl ...` |
| `scout` | `ghcr.io/stefanprodan/podinfo:6.15.0` | Its pod stays `Pending`. The container asks for more CPU than the node has |
| `bridge` | `ghcr.io/stefanprodan/podinfo:6.15.0` | Its pod stays `Pending`. It mounts a PersistentVolumeClaim that does not exist |
| `probe` | `mccutchen/go-httpbin:2.25.0` | The container restarts again and again. The liveness probe asks for a path the server does not have |
| `engine` | `curlimages/curl:8.22.0` | The container exits at once and the pod goes into `CrashLoopBackOff` |
| `cargo` | `node:22-alpine` | The container is stopped with `OOMKilled`. The memory limit is below what the process holds |
| `beacon` | `ghcr.io/stefanprodan/podinfo:6.15.99` | The pod is in `ImagePullBackOff`. The image tag does not exist |

Every workload except `shuttle` and `engine` has a Service of the same name in `starfleet`. The ports are `9898` for `scout`, `bridge` and `beacon`, and `8080` for `probe` and `cargo`.

## Helpers

This helper sends a request from `shuttle` to a Service and prints the HTTP status code. It prints `000` when the connection fails:

```sh
check_service() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 3 "http://$1/"
}
```

For example, `check_service scout:9898`. A fixed workload prints `200`.

## Practice tasks

- List all pods in `starfleet` and sort the broken ones by status, restart count and the age of the pod.
- For each broken pod, find the cause in the events or in `kubectl describe`, and write down the one line that names it.
- Fix `scout` and `bridge` so that both pods reach `Running`.
- Fix `probe` and `engine` so that they stop restarting. Read the previous container log of `engine`.
- Read the last state of `cargo` and its real memory use with `kubectl top`. Set a limit that fits the use. Do not remove the limit.
- Fix the image tag of `beacon` and watch the rollout finish.
- Send a request from `shuttle` to each fixed Service and check for `200`.

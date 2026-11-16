# Triage And Fix Failing Workloads

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 5 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| A Triage Order And Pending Pods | Schedule A Pending Workload |
| Diagnose A Crashing Process | Repair A Crashing Process |
| Repair A Failing Liveness Probe | Repair A Failing Liveness Probe |
| OOMKilled And Memory Limits | Repair An OOMKilled Workload |
| ImagePullBackOff And Image References | Repair An Image Reference |

## What you will prove

- Schedule A Pending Workload.
- Repair A Crashing Process.
- Repair A Failing Liveness Probe.
- Repair An OOMKilled Workload.
- Repair An Image Reference.

## Before you start

You need to know what a pod, a Deployment and a Service are, and how to read YAML. You need the basic commands `kubectl get`, `kubectl describe`, `kubectl logs` and `kubectl exec`.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. The metrics-server add-on is installed, so `kubectl top` works. No Prometheus stack runs, to save memory. The cluster starts broken on purpose, and you fix it step by step in the parts.

| Workload | What it is | What is wrong |
| --- | --- | --- |
| `shuttle` | A client pod with `curl` | Nothing. You send test requests from it |
| `scout` | `podinfo` 6.17.0, port `9898` | The pod stays `Pending` |
| `bridge` | `podinfo` 6.17.0, port `9898` | The pod stays `Pending` |
| `probe` | `go-httpbin` 2.26.0, port `8080` | The container is restarted again and again |
| `engine` | A small shell program | The container exits at once |
| `cargo` | A Node.js server, port `8080` | The container is stopped with `OOMKilled` |
| `beacon` | `podinfo` with a wrong tag, port `9898` | The pod is in `ImagePullBackOff` |

Launch the playground for the reading exercises:

<!-- astrona:playground -->

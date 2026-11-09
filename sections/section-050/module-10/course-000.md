# Triage And Fix Failing Workloads

A workload that does not run shows only a short word in the `STATUS` column: `Pending`, `CrashLoopBackOff`, `OOMKilled`, `ImagePullBackOff`. The word is a symptom. Many different causes lead to the same word, and the fix depends on the cause. On the exam you have a few minutes for each broken workload, so you need a fixed order of commands that finds the cause fast, and a proof that the fix works.

This module teaches that order. You read the status, then the events, then the description of the pod, then the logs. You then fix the cause and prove the fix with a request from the `shuttle` pod and with the state of the pod. You never stop at "the pod is `Running`", because a pod can be `Running` and still not serve.

The module has four parts. **A Triage Order And Pending Pods** sets the order of commands and fixes two pods that the scheduler cannot place. **CrashLoopBackOff And Failing Probes** reads exit codes, container logs and probe events, and fixes a container that exits and a container that a liveness probe restarts. **OOMKilled And Memory Limits** reads the last state of a container, measures its memory use and sets a limit that fits. **ImagePullBackOff And Image References** reads the pull error, fixes a wrong tag and ends with a graded lab on all four fault families.

## Learning objectives

After this module you can:

- Follow a fixed triage order (status, events, describe, logs, previous logs) to find the cause of a pod failure.
- Fix a `Pending` pod caused by a request that is too large, a missing PersistentVolumeClaim or a node selector that matches no node.
- Fix a `CrashLoopBackOff` caused by a process that exits or by a liveness probe that fails.
- Fix an `OOMKilled` container by reading its memory use and setting a limit that fits.
- Fix an `ImagePullBackOff` caused by a wrong tag, and tell a missing tag from a missing pull secret.
- Prove each fix with a request from `shuttle` and with the state of the pod.

## Before you start

You need to know what a pod, a Deployment and a Service are, and how to read YAML. You need the basic commands `kubectl get`, `kubectl describe`, `kubectl logs` and `kubectl exec`.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. The metrics-server add-on is installed, so `kubectl top` works. No Prometheus stack runs, to save memory. The cluster starts broken on purpose, and you fix it step by step in the parts.

| Workload | What it is | What is wrong |
| --- | --- | --- |
| `shuttle` | A client pod with `curl` | Nothing. You send test requests from it |
| `scout` | `podinfo` 6.17.0, port `9898` | The pod stays `Pending` |
| `bridge` | `podinfo` 6.17.0, port `9898` | The pod stays `Pending` |
| `probe` | `go-httpbin` 2.25.0, port `8080` | The container is restarted again and again |
| `engine` | A small shell program | The container exits at once |
| `cargo` | A Node.js server, port `8080` | The container is stopped with `OOMKilled` |
| `beacon` | `podinfo` with a wrong tag, port `9898` | The pod is in `ImagePullBackOff` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

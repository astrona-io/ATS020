# Summary

A failing workload shows a short status word, and the word is only a symptom. This module followed one order of evidence: the status from `kubectl get pods`, the events, the description of the pod with its state and last state, and the container logs. Each step is cheap, and the first one that names the cause ends the search. A fix goes into the object that owns the pod, almost always the Deployment, and it is proved with a request from `shuttle` and with the state of the pod, not with a `Running` status alone.

A `Pending` pod has not been placed on a node. The scheduler compares the resource requests of the pod with the allocatable amount of each node, not with real use. It also checks the node selector, the taints and the volumes. The `FailedScheduling` event names the failed check: `Insufficient cpu`, a PersistentVolumeClaim that is not found, or a selector that no node matches. A pod in this state has no container and no log.

A restart loop has two kinds of cause. The process of the container can end by itself, and then the exit code and the log name the cause. Or the kubelet can kill a healthy process because a liveness probe fails, and then the exit code can be `0`, with `Unhealthy` and `Killing` events that name the probe. The status `CrashLoopBackOff` is the wait between restarts, which doubles up to 5 minutes. `kubectl logs --previous` reads the run before the current one.

An `OOMKilled` container reached its memory limit, and the kernel stopped it with `SIGKILL`, exit code `137`. The reason appears in the last state of the container and not in the events, and the log is often empty. A correct fix measures the use with `kubectl top`, keeps a limit and gives it headroom above the highest reading. Removing the limit hides the fault and puts the node at risk.

An `ImagePullBackOff` means the kubelet cannot pull the image. The pull error in the events tells the cause apart: `not found` means the repository or tag does not exist, and `failed to authorize` with `403 Forbidden` means the registry wants credentials from a pull secret. The registry can also answer `403` for a repository that does not exist. The fix is an image tag that exists, never `latest`, or a pull secret in the pod template.

The key facts to remember are these:

- Read in this order: status, events, describe, logs, previous logs.
- The scheduler uses requests, and the kernel enforces limits.
- Exit code `137` is `SIGKILL`, and an `OOMKilled` reason shows only in the last state.
- A failing liveness probe restarts a healthy container, and the exit code can be `0`.
- A fix is proved by a `200` from `shuttle` and a pod that is `Ready` with no new restarts.

<!-- astrona:playground:destroy -->

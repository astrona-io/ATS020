# Prerequisites

You need these tools on your machine: `astrona`, `kubectl` and `curl`.

You need to read a pod's status, events and last state with `kubectl get pods` and `kubectl describe pod`. You need to know what a Deployment, a Service, an EndpointSlice, a memory limit, a liveness probe and an admission webhook are. You need to read container logs with `kubectl logs`, including `--previous`, and memory use with `kubectl top`.

The lab starts a single-node `kind` cluster with Kubernetes 1.35 and the metrics-server add-on. Allow a few minutes for the first start.

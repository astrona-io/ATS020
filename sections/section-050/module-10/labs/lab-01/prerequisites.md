# Prerequisites

You need these tools on your machine: `astrona`, `kubectl` and `curl`.

You need to know how to read a pod's status and events with `kubectl get pods` and `kubectl describe pod`. You need to know what a Deployment, a Service, a resource request, a memory limit and a liveness probe are. You need to read container logs with `kubectl logs`, including `--previous`.

The lab starts a single-node `kind` cluster with Kubernetes 1.35 and the metrics-server add-on. Allow a few minutes for the first start.

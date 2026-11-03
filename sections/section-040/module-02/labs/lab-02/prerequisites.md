# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know what a resource request and a resource limit are, how to read `kubectl top` and `kubectl describe node`, and how to run a PromQL query with `max_over_time()`. You also need to know how to change the resources of a Deployment with `kubectl set resources` or `kubectl edit`.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs Prometheus, kube-state-metrics and metrics-server and starts a traffic loop. Allow about five minutes for the first start. Usage data needs about ten minutes of traffic before the numbers are steady.

# Prerequisites

You need a working Astrona CLI and the container runtime required by its kind
backend. The lab creates one Kubernetes 1.35.8 node. Have `kubectl`, `curl` and
`jq` on the terminal PATH; bootstrap checks for them before applying anything.
No Helm installation is needed. Both container images are preloaded.

Know how to read a ConfigMap (a Kubernetes object holding configuration text),
edit YAML, restart a Deployment and change its replica count. Prometheus
collects metrics by requesting each target's `/metrics` path. You will read
its target list and run a query through its HTTP application programming
interface (API).

The starting state contains plain Prometheus, its discovery permissions and
three one-replica Deployments. Only `scout` is selected initially. There is no
Operator and there are no ServiceMonitor or PodMonitor resources.

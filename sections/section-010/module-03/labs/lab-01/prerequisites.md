# Prerequisites

Allow 25 minutes. You need Kubernetes namespaces, resource labels,
`kubectl apply`, `kubectl exec` and `kubectl logs`. You should know that
Prometheus evaluates rules and Alertmanager routes and suppresses
notifications. A rate is a counter's average increase per second.

Astrona supplies the Kubernetes terminal access. Bootstrap checks `kubectl`,
installs missing `curl` and `jq` on an apt-based terminal, and installs the
trimmed monitoring stack. `amtool` is available in the Alertmanager
container. On other hosts, install `curl` and `jq` before starting.

The lab starts with two scraped `scout` Pods, a continuous error request
loop, a working webhook receiver, a wrong team matcher and an already firing
maintenance alert. Do not start another cluster while this lab runs.

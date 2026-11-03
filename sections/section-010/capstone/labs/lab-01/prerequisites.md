# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to read and edit a ServiceMonitor, a PrometheusRule and an AlertmanagerConfig with `kubectl`. You need to know which label the Prometheus resource selects, how to write a recording rule and an alerting rule in PromQL, and how Alertmanager routes an alert by label to a receiver.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs the Prometheus Operator, one Prometheus and one Alertmanager. Allow about five minutes for the first start.

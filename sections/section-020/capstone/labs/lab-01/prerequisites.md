# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`.

You need to know how to write an OpenTelemetryCollector with the `file_log` receiver, the `k8s_attributes` processor and the `count` connector, how a ClusterRole and a ClusterRoleBinding give a service account read access, and how a ServiceMonitor reaches Prometheus. You need to know how Grafana loads a dashboard and a data source from a ConfigMap with a sidecar label, and what the data source UID does in a panel.

The lab starts a single-node `kind` cluster with Kubernetes 1.35. It installs cert-manager, the OpenTelemetry Operator, Prometheus and Grafana, so allow about six minutes for the first start.

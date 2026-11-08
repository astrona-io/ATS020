# Prerequisites

- `kubectl` 1.35, `curl` and `jq` on your `PATH`.
- A single-node `kind` cluster running Kubernetes 1.35. The lab creates it.
- A trimmed Prometheus stack in `monitoring`: the Prometheus Operator, one Prometheus and Grafana 13.2.3 with the dashboard and data source sidecars. Grafana's user is `admin` and its password is `starfleet`. The lab installs them.
- `scout` in `starfleet` and in `outpost`, and `shuttle` in `starfleet`. `shuttle` sends steady requests, including errors and slow requests.
- A ConfigMap `datasource-prometheus` in `monitoring` that provisions the Grafana data source with the UID `prometheus`.
- A ConfigMap `dashboard-scout-overview` in `monitoring` that holds the dashboard `scout-overview`. The lab creates it with two faults.

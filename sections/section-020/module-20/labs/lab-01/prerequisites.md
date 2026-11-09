# Prerequisites

- `kubectl` 1.35, `curl` and `jq` on your `PATH`.
- A single-node `kind` cluster running Kubernetes 1.35. The lab creates it.
- cert-manager 1.21.3, the OpenTelemetry Operator 0.160.0 and a trimmed Prometheus stack (the Prometheus Operator and one Prometheus) in `monitoring`. The lab installs them.
- `probe` in `outpost`, `scout` and `shuttle` in `starfleet`. `shuttle` sends a request to `probe` every second and asks for a `500` response every fourth second.
- An `OpenTelemetryCollector` named `logs` in `monitoring`, a ClusterRole `logs-collector` and a ServiceMonitor `logs-collector`. The lab creates them with two faults.

# Question

Solve this question on: `terminal`

The `logs` Collector runs as a DaemonSet in `monitoring`. It reads `probe` error logs and exposes `log_error_lines_total` for Prometheus.

## Tasks

1. Inspect the Collector logs and test its service account permissions.
2. Bind `monitoring/logs-collector` to the existing read-only pod ClusterRole.
3. Verify the account can list and watch pods but cannot read Secrets or modify pods.
4. Query `log_error_lines_total{k8s_namespace_name="outpost",k8s_deployment_name="probe"}` and confirm it rises.

## Constraints

- Keep the DaemonSet, `file_log` receiver, `k8s_attributes` processor and `count` connector.
- The service account may only read pods across namespaces.
- Keep the existing Prometheus and Collector endpoint.

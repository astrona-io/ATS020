# Question

Solve this question on: `terminal`

The `logs` Collector runs as a DaemonSet in `monitoring`. It reads `probe` error logs and exposes `log_error_lines_total` for Prometheus.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Compare the ServiceMonitor label with the Prometheus selector.
2. Make Prometheus select the existing `logs-collector` monitor.
3. Verify exactly one healthy `logs-collector` target.
4. Query the labelled `log_error_lines_total` counter twice and confirm it rises.

## Constraints

Keep the DaemonSet, `file_log` receiver, `k8s_attributes` processor and `count` connector. The service account may only read pods across namespaces. Keep the existing Prometheus and Collector endpoint.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

# Question

Solve this question on: `terminal`

The `outpost` team wants to see how often `probe` logs an error. A Collector named `logs` already runs as a DaemonSet in the namespace `monitoring`. It reads the container log files on the node, adds Kubernetes metadata to each record and counts every log line that contains `level=ERROR` into the metric `log_error_lines_total`. The Collector exposes that metric on port `8889`, and a ServiceMonitor named `logs-collector` should make Prometheus scrape it.

Prometheus does not show the metric the team needs. The query below must return a value that keeps rising, because `probe` logs an error line every 4 seconds:

```text
log_error_lines_total{k8s_namespace_name="outpost", k8s_deployment_name="probe"}
```

Find out why the series is missing or incomplete and fix it. Prove the fix in Prometheus. The cluster is a single node. Prometheus is the Service `kps-prometheus` on port `9090` in `monitoring`.

Requirements:

- Prometheus has exactly one target for the job `logs-collector`, and the target is up.
- The series above exists and rises while `probe` returns errors.
- The Collector keeps its DaemonSet mode, its `file_log` receiver, its `k8s_attributes` processor and the `count` connector.
- The Collector's service account may read pods in every namespace and nothing more. It must not get a broad role such as `cluster-admin`.

Telemetry arrives late. Prometheus scrapes every 15 seconds in this lab, and a changed ServiceMonitor reaches Prometheus after about a minute. Wait and query again before you decide a fix did not work.

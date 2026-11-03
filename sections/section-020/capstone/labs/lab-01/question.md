# Question

Solve this question on: `terminal`

The on-call team of the `outpost` namespace wants one Grafana dashboard that shows how `scout` and `probe` behave. `scout` is a service with Prometheus metrics. `probe` is a service that has no metrics, but it writes one log line for every request, with `level=ERROR` when the response is a `5xx`. The pod `shuttle` in `starfleet` sends steady traffic to both, and every fourth second it asks each of them for a `500` response.

Prometheus, Grafana and the OpenTelemetry Operator run in the namespace `monitoring`, together with cert-manager. Prometheus is the Service `kps-prometheus` on port `9090`, and it selects only ServiceMonitors that carry the label `release: kps`. Grafana is the Service `kps-grafana` on port `80`, with the user `admin` and the password `starfleet`. Its data source `prometheus` already exists. The team already applied the ConfigMap `dashboard-outpost-overview` in `monitoring`. The dashboard does not show up in Grafana, and nothing collects the logs of `probe` yet.

## Task

1. Create an OpenTelemetryCollector named `logs` in the namespace `monitoring`. It runs as a DaemonSet, reads the container log files on the node, adds the Deployment name to every record and turns every log line that contains `level=ERROR` into the metric `log_error_lines_total`. The Collector serves that metric on port `8889`.
2. Give the Collector's service account the permission it needs to read pods, and nothing more.
3. Make Prometheus scrape the Collector's metric port, so that `log_error_lines_total{k8s_namespace_name="outpost", k8s_deployment_name="probe"}` exists in Prometheus and keeps rising.
4. Fix the dashboard ConfigMap until Grafana loads the dashboard `outpost-overview` as a provisioned dashboard, and until all three of its panels (`Request rate`, `Error ratio` and `Error log lines`) show data.

## Constraints

- Keep the Collector in DaemonSet mode, with the `file_log` receiver, the `k8s_attributes` processor and the `count` connector. Use the image `otel/opentelemetry-collector-contrib:0.162.0`.
- The Collector's service account may read pods in every namespace and nothing more. It must not get a broad role such as `cluster-admin`.
- Keep the dashboard as the ConfigMap `dashboard-outpost-overview` with its three panels and its UID `outpost-overview`. Do not create the dashboard by hand in the Grafana web interface, and do not change the data source.
- The panel `Error log lines` must query the metric `log_error_lines_total`.

## How the answer is checked

The grader runs six checks. The first reads the Prometheus targets and needs one healthy target on port `8889`. The second reads `log_error_lines_total` for `probe` in `outpost` twice, 45 seconds apart, and needs the value to rise. The third reads the OpenTelemetryCollector and the permissions of its service account. The fourth asks Grafana whether the dashboard `outpost-overview` is provisioned. The fifth sends the query of every panel to its data source and needs data from each. The sixth checks that the data source is read-only, which Grafana reports for a provisioned data source.

Telemetry arrives late. Prometheus scrapes every 15 seconds in this lab, a new ServiceMonitor reaches Prometheus after about a minute, and the Grafana sidecar needs a few seconds to load a ConfigMap. Wait and query again before you decide a fix did not work.

Hint: reach Grafana with `kubectl -n monitoring port-forward svc/kps-grafana 3000:80` and Prometheus with `kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090`.

# Question

Solve this question on: `terminal`

The `starfleet` team keeps its request dashboard as code. The dashboard `Scout Overview` has the UID `scout-overview` and lives in the ConfigMap `dashboard-scout-overview` in the namespace `monitoring`. It has three panels: `Request rate`, `Error ratio` and `Latency`. Grafana should load it from that ConfigMap, and every panel should show data from Prometheus.

The dashboard does not appear in Grafana. Find out why, fix it, and prove that all three panels return data. Grafana is the Service `kps-grafana` in `monitoring` (port `80`). Sign in as `admin` with the password `starfleet`. The data source `Prometheus` has the UID `prometheus` and is already provisioned from the ConfigMap `datasource-prometheus`.

Requirements:

- Grafana loads the dashboard `scout-overview` from the ConfigMap `dashboard-scout-overview`, and the API reports it as provisioned.
- The dashboard keeps its three panels. Every panel query returns data when `$namespace` is `starfleet`.
- The panels use the provisioned data source. Do not create a second data source by hand, and do not save the dashboard through the Grafana API or web interface, because Grafana's database is lost when the pod is replaced.

The dashboard sidecar copies a ConfigMap after a few seconds. Wait and query again before you decide a fix did not work.

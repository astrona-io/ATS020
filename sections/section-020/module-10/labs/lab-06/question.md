# Question

Solve this question on: `terminal`

Grafana loads the request dashboard, but its provisioned Prometheus data source is missing. The data source ConfigMap exists in `monitoring`.

## Tasks

1. Inspect the data source ConfigMap and the sidecar selector.
2. Label the ConfigMap so the data source sidecar loads it.
3. Verify the data source UID is `prometheus` and Grafana reports it as read-only.
4. Run a dashboard query and confirm Prometheus returns data.

## Constraints

- Keep the data source in `datasource-prometheus`.
- Do not add a second data source through the API or web interface.
- Keep its UID and Prometheus URL.

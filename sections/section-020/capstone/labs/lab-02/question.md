# Question

Solve this question on: `terminal`

## Scenario

This is a Section 020 capstone, one integrated incident with no step-by-step guidance.

Requests in the namespace `outpost` are failing. The services `scout`, `probe` and `cargo` report the counter `fleet_requests_total` with a `status` label, and Prometheus adds the labels `namespace` and `service`. Their logs are in Loki with the labels `namespace`, `pod` and `container`. An error line contains the exact text `ERROR`, in capital letters.

Grafana is the Service `kps-grafana` in `monitoring` (port `80`, user `admin`, password `starfleet`). It has a provisioned Prometheus data source with the unique identifier (UID) `prometheus`. Prometheus is the Service `kps-prometheus` in `monitoring` (port `9090`). Loki is the Service `loki` in `logging` (port `3100`).

You can use the Grafana web interface or its API. The data source API is `/api/datasources/` for creating, and the dashboard API is `/api/dashboards/uid/incident-overview` for reading and `/api/dashboards/db` for saving.

## Tasks

1. **Connect Loki.** Add a data source named `Loki` of type `loki` with the UID `loki`, the address `http://loki.logging:3100` and **Maximum lines** (`jsonData.maxLines`) set to `500`. Create it through the API, because the web interface generates its own UID. You can set Maximum lines in either place.
2. **Correct the dashboard.** The saved dashboard `Incident Overview` has the UID `incident-overview`. Change the query of the panel `Failed requests` so that it shows the per-second rate of `status="500"` requests in `outpost`, with one series per `service`. Change the query of the panel `Error lines` to a log query that shows only error lines from `outpost`. Save the dashboard in Grafana, and do not provision it from a file.
3. **Record the service.** Find the failing service with a Prometheus query. Save the name of its Deployment, and nothing else, to `/tmp/ats-020-incident-service.txt`.
4. **Record the cause.** Read the error lines in Loki. Save the value of `path=` from those lines, and nothing else, to `/tmp/ats-020-incident-path.txt`.
5. **Fix the service.** Compare the failing Deployment with a healthy one and correct the environment value. Do not change `shuttle`, the other services or the number of replicas.

The grader expects no failed request and no new error line during the last minute, and a successful request rate on all three services. These windows clear about one minute after the new Pod starts.

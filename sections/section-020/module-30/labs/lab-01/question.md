# Question

Solve this question on: `terminal`

## Scenario

Some workloads in the namespace `outpost` are writing error lines, and the on-call dashboard does not show them. Grafana is the Service `kps-grafana` in `monitoring` (port `80`, user `admin`, password `starfleet`). It has a Loki data source with the unique identifier (UID) `loki`, and a saved dashboard `Outpost Logs` with the UID `outpost-logs`. Loki is the Service `loki` in `logging` (port `3100`). Log streams have the labels `namespace`, `pod` and `container`.

An error line contains the exact text `ERROR`, in capital letters. A line that only contains lower-case `error` is not an error line.

You can use the Grafana web interface or its API for tasks 1 and 2. The data source API is `/api/datasources/uid/loki` and the dashboard API is `/api/dashboards/uid/outpost-logs` for reading and `/api/dashboards/db` for saving.

## Tasks

1. **Change the data source.** Set **Maximum lines** (`jsonData.maxLines`) of the Loki data source to `250`. Keep its address and leave it editable.
2. **Correct the panels.** On the saved dashboard, change the query of the panel `Error lines` to a log query that shows only error lines from `outpost`. Change the query of the panel `Streams with errors` to `count(rate({namespace="outpost"} |= "ERROR" [5m]))`. Save the dashboard in Grafana, and do not provision it from a file.
3. **Stop the failing workloads.** Use a Loki query to find which Pods in `outpost` write error lines. Scale the controller of each of those Pods to `0` replicas. Leave every other controller in `outpost` running, and do not change `starfleet`.

Do not delete any controller.

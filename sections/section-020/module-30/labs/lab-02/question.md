# Question

Solve this question on: `terminal`

Loki stores logs with `namespace`, `pod` and `container` labels. Grafana has the editable `loki` data source and the saved `outpost-logs` dashboard.

## Tasks

1. Query Loki for uppercase `ERROR` lines in `outpost`.
2. Follow each matching Pod owner to its Deployment or StatefulSet.
3. Scale only the controllers that wrote those error lines to zero.
4. Verify those Pods are gone and every other controller in `outpost` and `starfleet` keeps its original replicas.

## Constraints

- An error contains the exact uppercase text `ERROR`; lower-case `error` does not match.
- Keep all controllers.
- Do not change workloads in `starfleet`.
- Keep the data source URL and editable dashboard.

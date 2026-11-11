# Question

Solve this question on: `terminal`

The lab creates ten real Git revisions and Argo CD deployments, including two failed builds and their reverts. Startup includes this history generation.

## Tasks

1. Export the Application history and use the commit messages to identify the two failed builds and their reverts.
2. Calculate deployment-to-deployment seconds for history ids 2 → 3 and 6 → 7.
3. Calculate the mean, then save both measurements in `report.json`.
4. Create ConfigMap `delivery-evidence` in `starfleet` with a `report.json` key and explain why commit time is not recovery time.

## Constraints

- Each measurement has `failed_id`, `restored_id` and numeric `seconds`, ordered by failed id.
- The report has `measurements` and numeric `mean_seconds`.
- Keep Git and the Application history unchanged.
- Calculate from this cluster; do not reuse example durations.

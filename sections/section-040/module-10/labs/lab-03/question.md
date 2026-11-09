# Question

Solve this question on: `terminal`

The lab creates ten real Git revisions and Argo CD deployments, including two failed builds and their reverts. Startup includes this history generation.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Export all ten Application history entries and the matching Git commits.
2. Join entries by the full revision hash and calculate commit-to-deployment seconds using the committer date.
3. Calculate the mean, then save the ordered measurements and mean in `report.json`.
4. Create ConfigMap `delivery-evidence` in `starfleet` with a `report.json` key and check the submitted data.

## Constraints

Each measurement has `id`, `revision` and numeric `seconds`, ordered by history id. The report has `measurements` and numeric `mean_seconds`. Keep Git and the Application history unchanged. Calculate from this cluster; do not reuse example durations.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

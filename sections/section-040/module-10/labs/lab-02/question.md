# Question

Solve this question on: `terminal`

Argo CD has synced ten revisions of `scout`. The recording rule selects failed sync operations, so it does not count the deployments.

## Tasks

1. Inspect the Application history and the labels on `argocd_app_sync_total`.
2. Repair `dora:deployments:increase6h` to count successful syncs over six hours using `increase()` and `round()`.
3. Compare the recorded value with the direct counter query.
4. Explain why a successfully applied deployment can still leave the application unhealthy.

## Constraints

- Keep the Application, Git history and counter data unchanged.
- Use the source counter, not a constant count.

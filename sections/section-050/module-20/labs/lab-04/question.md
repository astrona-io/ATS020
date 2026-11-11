# Question

Solve this question on: `terminal`

The `scout` Application reports a comparison error after its source path changed. The last successfully deployed workload still runs.

## Tasks

1. Inspect the Application conditions and distinguish source comparison from workload health.
2. Inspect the Git repository and identify the directory that contains the scout manifests.
3. Repair the Application source path and request a refresh without changing the repository or disabling automated sync.
4. Verify `Synced`, `Healthy`, the deployed Git revision and an HTTP 200 response from scout.

## Constraints

- Keep the original repository URL, `main` revision, destination namespace and automated sync.
- Do not replace the Application or repair only the live Deployment.

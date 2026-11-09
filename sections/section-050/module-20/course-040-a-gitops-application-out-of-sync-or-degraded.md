# Recover A GitOps Source Path

The `scout` workload still serves requests, but Argo CD cannot compare its desired state with Git. The Application's source directory was changed to `scout-missing`. This is a source-comparison failure, so editing the running Deployment cannot repair it.

Argo CD reports sync and health separately. Sync compares desired and live resources. Health describes whether the resources satisfy their readiness checks. An Application can have healthy existing pods while Git comparison fails, or be synced while a newly applied Deployment is unhealthy.

This exercise uses a dedicated lab with Gitea and Argo CD. The platform-incident playground does not install them.

<!-- astrona:playground:renew -->

```sh
astrona stop ats-020-playground-050-02
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-20/labs/lab-04
```

## Locate the failure before changing the workload

Read the Application's source, conditions, sync and health in one request:

```sh
kubectl -n argocd get application scout -o json | jq '{source: .spec.source, conditions: .status.conditions, sync: .status.sync, health: .status.health}'
```

The `ComparisonError` condition identifies a failure to generate the desired manifests. Check the repository URL, revision and path before investigating pod health. A source path is relative to the repository root, not to a directory on your terminal.

Inspect the actual repository tree and revision:

```sh
kubectl -n gitea exec deploy/gitea -- git -C /tmp/work ls-tree --name-only HEAD
kubectl -n gitea exec deploy/gitea -- git -C /tmp/work rev-parse HEAD
```

The tree contains `scout`. The lab keeps the repository checkout inside Gitea so you can inspect it without configuring a second Git client.

## Restore comparison and verify reconciliation

Save this merge patch as `application-source.yaml`:

```yaml
spec:
  source:
    path: scout
```

Apply it and request a fresh comparison:

```sh
kubectl -n argocd patch application scout --type=merge --patch-file application-source.yaml
kubectl -n argocd annotate application scout argocd.argoproj.io/refresh=hard --overwrite
```

The annotation requests a refresh; it does not make an invalid source valid. Wait for the controller to compare the corrected directory, then check both dimensions again:

```sh
kubectl -n argocd get application scout -o json | jq '{conditions: .status.conditions, sync: .status.sync, health: .status.health}'
kubectl -n starfleet rollout status deployment/scout --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://scout:9898/
```

Look for `Synced`, `Healthy`, no remaining error condition and HTTP `200`. Compare `.status.sync.revision` with the repository's full commit hash. That proves the controller can read the intended revision and that the deployed service works.

If the repository manifest itself had the fault, repair or revert that manifest in Git and let the controller apply it. A live-only patch can be overwritten. In this lab the faulty field belongs to the Application, so the repair changes its source path while keeping automated sync enabled.

## Common pitfalls

> [!WARNING]
> - Do not treat `Healthy` as proof that Git comparison succeeded.
> - A refresh retries comparison; it does not repair a bad URL, revision or directory.
> - Do not disable automated sync or replace the Application to hide the condition.
> - Verify the deployed revision and a service request as well as status labels.

## Your mission: Recover A GitOps Source Path

The `scout` Application reports a comparison error after its source path changed. The last successfully deployed workload still runs.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Use the lab started above.

Submit after verifying the result:

```sh
astrona submit -c sections/section-050/module-20/labs/lab-04
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-050-02-04
astrona start ats-020-playground-050-02
```

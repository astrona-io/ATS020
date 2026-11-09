# Solution: Recover A GitOps Source Path

## Inspect the starting state

```sh
kubectl -n argocd get application scout -o json | jq '{source: .spec.source, sync: .status.sync, health: .status.health, conditions: .status.conditions}'
kubectl -n gitea exec deploy/gitea -- git -C /tmp/work ls-tree --name-only HEAD
```

## Make the repair

```sh
kubectl -n argocd patch application scout --type=merge -p '{"spec":{"source":{"path":"scout"}}}'
kubectl -n argocd annotate application scout argocd.argoproj.io/refresh=hard --overwrite
```

## Verify the result

```sh
kubectl -n argocd get application scout
kubectl -n starfleet exec deploy/shuttle -- curl -fsS http://scout:9898/
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-050/module-20/labs/lab-04
```

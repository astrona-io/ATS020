# Solution: Measure Time To Restore Service

## Inspect the starting state

```sh
kubectl -n argocd get application scout -o json | jq .status.history > history.json
kubectl -n gitea exec deploy/gitea -- curl -fsS 'http://localhost:3000/api/v1/repos/starfleet/starfleet-deploy/commits?limit=20&stat=false&verification=false&files=false' > commits.json
```

## Make the repair

```sh
jq '{measurements: [([2,3], [6,7]) as $pair | {failed_id: $pair[0], restored_id: $pair[1], seconds: ((.[] | select(.id == $pair[1]) | .deployedAt | fromdate) - (.[] | select(.id == $pair[0]) | .deployedAt | fromdate))}]} | . + {mean_seconds: ([.measurements[].seconds] | add / length)}' history.json > report.json
kubectl -n starfleet create configmap delivery-evidence --from-file=report.json
```

## Verify the result

```sh
kubectl -n starfleet get configmap delivery-evidence -o jsonpath='{.data.report\.json}' | jq .
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-040/module-10/labs/lab-04
```

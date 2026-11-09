# Solution: Calculate Lead Time From Git Revisions

## Inspect the starting state

```sh
kubectl -n argocd get application scout -o json | jq .status.history > history.json
kubectl -n gitea exec deploy/gitea -- curl -fsS 'http://localhost:3000/api/v1/repos/starfleet/starfleet-deploy/commits?limit=20&stat=false&verification=false&files=false' > commits.json
```

## Make the repair

```sh
jq --slurpfile commits commits.json '{measurements: [.[] | . as $d | ($commits[0][] | select(.sha == $d.revision)) as $c | {id: $d.id, revision: $d.revision, seconds: (($d.deployedAt | fromdate) - ($c.commit.committer.date | fromdate))}]} | . + {mean_seconds: ([.measurements[].seconds] | add / length)}' history.json > report.json
kubectl -n starfleet create configmap delivery-evidence --from-file=report.json
```

## Verify the result

```sh
kubectl -n starfleet get configmap delivery-evidence -o jsonpath='{.data.report\.json}' | jq .
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-040/module-10/labs/lab-03
```

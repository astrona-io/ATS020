# Measure Time To Restore Service

The fixture's failed deployments have history ids `2` and `6`; their reverts have ids `3` and `7`. Calculate each interval from the failed deployment to the deployed repair. A revert commit that has not reached the cluster has not restored service.

<!-- astrona:playground:renew -->

```sh
kubectl -n argocd get application scout -o json | jq '.status.history' > history.json
```

## Pair the failure with its recovery


Time to restore service is the time between the deployment that broke production and the deployment that fixed it. In the history, a bad deployment is followed by a revert. The bad deployments are the ids `2` and `6`, and their reverts are the ids `3` and `7`. The next command subtracts the `deployedAt` of each bad deployment from the `deployedAt` of the revert:

```sh
jq -r '[([2,3], [6,7]) as $p | ((.[] | select(.id == $p[1]) | .deployedAt | fromdate) - (.[] | select(.id == $p[0]) | .deployedAt | fromdate))] | @tsv' history.json
```

```text
54	53
```

The first failure lasted 54 seconds and the second lasted 53 seconds. The playground sets `progressDeadlineSeconds` to 30 seconds, so the Application first stays `Progressing` for about 30 seconds and then turns `Degraded` until the revert is deployed. A real incident lasts much longer, because people must notice the fault and decide to revert.

Two limits apply. The history does not say which entry was bad, so you must know it from the health data or from the commit messages. And this method assumes that a revert (or a fix) is the next deployment. If two failures happen in a row, restore time starts at the first and ends at the first healthy deployment.


## Common pitfalls

> [!WARNING]
> - History ids are not array positions. Select entries by `.id`.
> - Argo CD history records deployment times, not the exact moment users recovered. This fixture uses deployment time as its recovery boundary.
> - Validate the failure/recovery pairs with health evidence or the known incident history.
> - Do not average intervals until every incident has a matching recovery.

## Your mission: Measure Time To Restore Service

The lab creates ten real Git revisions and Argo CD deployments, including two failed builds and their reverts. Startup includes this history generation.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-040-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-10/labs/lab-04
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-040/module-10/labs/lab-04
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-040-01-04
astrona start ats-020-playground-040-01
```

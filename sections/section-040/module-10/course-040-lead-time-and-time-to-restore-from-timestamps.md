# Lead Time And Time To Restore From Timestamps

Prometheus counts events well, but lead time and time to restore are durations between two moments. Prometheus has no metric for the time of a commit, and a gauge does not keep the time of a past failure in a form you can subtract. The data for both durations lives in timestamps: the commit time in Git, and the deployment times in the Application history. This part calculates both from those timestamps.

## Lead time: from commit to deployment

Lead time for changes is the time between a commit and the moment that commit is deployed. The commit time is the committer date from Git. The deployment time is `deployedAt` in the Application history. The two sources share one key, the full commit hash: the field `revision` in the history is the hash of the deployed commit.

The Application history comes from `kubectl`. The commit list comes from the Gitea API, so start a port-forward to Gitea in a second terminal and leave it running. If port `3000` is in use on your machine, choose another local port and use it in the URL below:

<!-- astrona:playground:renew -->

```sh
kubectl -n gitea port-forward svc/gitea 3000:3000
```

Save both sources as JSON files, so that you can query them twice without calling the servers again:

```sh
kubectl -n argocd get application scout -o json | jq '.status.history' > history.json
curl -s "http://127.0.0.1:3000/api/v1/repos/starfleet/starfleet-deploy/commits?limit=20&stat=false&verification=false&files=false" > commits.json
```

Now join them. For every history entry, the `jq` program finds the commit with the same hash, then subtracts the commit time from the deployment time. The function `fromdate` turns a timestamp such as `2026-11-02T19:48:46Z` into seconds, so the difference is in seconds. The columns are the history `id`, the short hash, the commit message and the lead time in seconds:

```sh
jq -r --slurpfile commits commits.json '.[] | . as $deploy | ($commits[0][] | select(.sha == $deploy.revision)) as $commit | [$deploy.id, $deploy.revision[0:7], ($commit.commit.message | rtrimstr("\n")), (($deploy.deployedAt | fromdate) - ($commit.commit.committer.date | fromdate))] | @tsv' history.json
```

```text
0	febe9c0	Start scout 6.17.0	2794
1	8bede20	Change the welcome message	1801
2	c36bf2a	Try a new image build	720
3	8310751	Revert the new image build	241
4	d091bc7	Run two replicas	1501
5	d358bed	Change the welcome message again	601
6	81fae5f	Try another image build	481
7	e65a4cf	Revert the other image build	181
8	7877936	Change the welcome message once more	1202
9	736f9f2	Run three replicas	362
```

The first change waited 2794 seconds, about 47 minutes, and the revert of the first bad build waited 241 seconds, about 4 minutes. A single lead time says little, so teams report the median or the mean over a window. This command averages the ten values:

```sh
jq -r --slurpfile commits commits.json '[.[] | . as $deploy | ($commits[0][] | select(.sha == $deploy.revision)) as $commit | (($deploy.deployedAt | fromdate) - ($commit.commit.committer.date | fromdate))] | add / length' history.json
```

```text
988.4
```

The mean lead time is 988 seconds, about 16.5 minutes. The committer dates in the playground are set earlier than the push on purpose, between 3 and 45 minutes. In a real repository the committer date is the moment the developer committed, and the waiting time comes from review, tests and approval. If your team squashes commits when it merges, use the date of the merge commit, because that is the commit Argo CD deploys.

## Time to restore: from a bad deployment to the next healthy one

Time to restore service is the time between the deployment that broke production and the deployment that fixed it. In the history, a bad deployment is followed by a revert. The bad deployments are the ids `2` and `6`, and their reverts are the ids `3` and `7`. The next command subtracts the `deployedAt` of each bad deployment from the `deployedAt` of the revert:

```sh
jq -r '[(.[3].deployedAt | fromdate) - (.[2].deployedAt | fromdate), (.[7].deployedAt | fromdate) - (.[6].deployedAt | fromdate)] | @tsv' history.json
```

```text
54	53
```

The first failure lasted 54 seconds and the second lasted 53 seconds. The playground sets `progressDeadlineSeconds` to 30 seconds, so the Application first stays `Progressing` for about 30 seconds and then turns `Degraded` until the revert is deployed. A real incident lasts much longer, because people must notice the fault and decide to revert.

Two limits apply. The history does not say which entry was bad, so you must know it from the health data or from the commit messages. And this method assumes that a revert (or a fix) is the next deployment. If two failures happen in a row, restore time starts at the first and ends at the first healthy deployment.

## The same metrics with Flux

Flux is another GitOps controller. It exposes a gauge named `gotk_reconcile_condition`, which shows for every object whether its Ready condition is true or false. The playground does not install Flux, so this module shows no output from it. The idea is the same as for Argo CD: the failure signal is the health or Ready condition going false, not a failed apply.

## One change that improves each metric

Each metric has a typical change in the delivery process that moves it in the right direction. Deployment frequency improves when changes are smaller, because a small change is easier to review and safe to deploy often. Lead time improves when waiting time shrinks, for example when automated sync replaces a manual deployment step and when review does not wait for a single person. Change failure rate improves when a check catches the fault before the merge, for example a pipeline step that confirms the image tag exists. Time to restore improves when the revert is the default response: with GitOps it is one `git revert` and one push, and an alert on `Degraded` tells the team within minutes.

You can now calculate all four DORA metrics from the data in the cluster: two from Prometheus and two from timestamps. The numbers are the start of a conversation. A rising change failure rate with a falling lead time, for example, says the team gives up quality for speed.

## Common pitfalls

> [!WARNING]
> - **Joining Git and the history on time or message.** Join on the full commit hash, the field `revision`.
> - **Using the author date or the push time as the commit time.** Use the committer date of the commit that Argo CD deployed. After a squash merge, that is the merge commit.
> - **Reporting one lead time.** A single change can be an outlier. Use the median or the mean over a window.
> - **Reading time to restore from the revert commit time.** The service is restored when the revert is deployed (`deployedAt`), not when it is committed.
> - **Trusting the history for a long window.** Older entries are dropped when the history exceeds `revisionHistoryLimit`.

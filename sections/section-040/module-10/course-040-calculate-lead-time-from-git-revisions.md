# Calculate Lead Time From Git Revisions

Join the deployed revision in Argo CD with the full commit hash in Git. Subtract the committer date from `deployedAt` to measure how long that change waited to reach the cluster.

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


## Common pitfalls

> [!WARNING]
> - Join by the full revision hash, not by message or list position.
> - Use the committer date of the revision that was actually deployed.
> - Check that every history entry has one matching commit before calculating the mean.

## Your mission: Calculate Lead Time From Git Revisions

The lab creates ten real Git revisions and Argo CD deployments, including two failed builds and their reverts. Startup includes this history generation.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-040-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-10/labs/lab-03
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-040/module-10/labs/lab-03
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-040-01-03
astrona start ats-020-playground-040-01
```

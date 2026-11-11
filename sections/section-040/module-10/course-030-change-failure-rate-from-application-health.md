# Change Failure Rate From Application Health

Two seeded deployments applied successfully but made `scout` unhealthy. Count the known degraded episodes and compare them with successful deployments. A failed-sync counter measures a different event and misses these application failures.

## A failed deployment with a successful sync

The playground history contains two bad deployments. The commits "Try a new image build" and "Try another image build" change the image of `scout` to a tag that does not exist. The commands in this part use two port-forwards, one to Gitea on port `3000` and one to Prometheus on port `9090`. The `&` at the end of each line runs the command in the background of your terminal, so you can keep typing:

<!-- astrona:playground:renew -->

```sh
kubectl -n gitea port-forward svc/gitea 3000:3000 &
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 &
```

Now read the file at the first bad commit. The first command finds the hash of that commit in Gitea, and the second prints the image line of the file at that hash:

```sh
BAD_COMMIT=$(curl -s "http://127.0.0.1:3000/api/v1/repos/starfleet/starfleet-deploy/commits?limit=20&stat=false&verification=false&files=false" | jq -r '.[] | select(.commit.message | startswith("Try a new image build")) | .sha')
curl -s "http://127.0.0.1:3000/api/v1/repos/starfleet/starfleet-deploy/raw/scout/scout.yaml?ref=$BAD_COMMIT" | grep -n "image:"
```

```text
21:          image: ghcr.io/stefanprodan/podinfo:6.17.0-missing
```

The tag `6.17.0-missing` does not exist in the image registry. When this commit is deployed, the kubelet cannot pull the image, and the new pods stay in `ImagePullBackOff`. In this fixture the sync operation completes with phase `Succeeded`, even though the resulting workload later becomes unhealthy. Ask Prometheus for syncs that ended in `Failed` or `Error`. Define the `promql` helper first, if your shell is new:

```sh
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.container, .endpoint, .instance, .job, .pod, .service, .exported_namespace, .namespace, .dest_server, .dry_run, .project)), value: .value[1]}'
}
promql 'argocd_app_sync_total{name="scout",phase=~"Failed|Error"}'
```

The query prints nothing. No series exists, because every sync of this Application ended in `Succeeded`. A change failure rate built on that counter is always `0`, and the team would think delivery is perfect. The sync phase tells you whether Argo CD could apply the change. It does not tell you whether the change works.

## The health status shows the failure

Argo CD also checks the health of the resources it applied. For a Deployment, the health is `Progressing` while the rollout runs, `Healthy` when the new pods are ready, and `Degraded` when the rollout does not finish before `progressDeadlineSeconds`. The playground sets that field to 30 seconds. So a bad image tag gives `Progressing` for 30 seconds, then `Degraded`.

The metric `argocd_app_info` carries the health. It is a gauge with the value `1` and one series for each combination of health status and sync status that the Application had. The next command counts how many scrapes each health status was present for. At a 15-second scrape interval, a count of `3` means about 45 seconds:

```sh
promql 'sum by (health_status) (count_over_time(argocd_app_info{name="scout"}[6h]))'
```

```text
{"metric":{"health_status":"Unknown"},"value":"3"}
{"metric":{"health_status":"Healthy"},"value":"55"}
{"metric":{"health_status":"Progressing"},"value":"6"}
{"metric":{"health_status":"Degraded"},"value":"3"}
```

The Application was `Degraded` for 3 scrapes. The health status is the signal that records the failed changes. The `Healthy` count grows with time, because the series stays present while the Application is healthy.

## From a health gauge to a count of failures

A series for `health_status="Degraded"` exists only while the Application is degraded. Outside those moments the query returns nothing, and a function such as `changes()` has nothing to count. The fix is to build a flag that is always present: `1` while the Application is `Degraded` and `0` otherwise. The second part of the expression below takes any `argocd_app_info` series of the Application and multiplies it by `0`. The `or` operator uses it when the first part has no series. Both sides use `max by (name)` to leave one series.

The flag is `0` while the Application is healthy. In this seeded history, each known failed deployment produces one complete `0` to `1` to `0` episode. That is two changes for each failure. The function `changes()` counts how often a value changed in a range. A subquery `[6h:15s]` evaluates the flag every 15 seconds over the last 6 hours, so `changes()` can run on it. Divide the number of changes by two:

```sh
promql 'sum(changes((max by (name) (argocd_app_info{name="scout",health_status="Degraded"}) or max by (name) (argocd_app_info{name="scout"}) * 0)[6h:15s])) / 2'
```

```text
{"metric":{},"value":"2"}
```

The result is `2` failed deployments. This matches the two bad commits. If a deployment is still `Degraded` when you run the query, the flag changed only once for it, and the query counts it as half a failure. Wait until the Application is healthy again before you trust the number.

## The ratio as a recording rule

The change failure rate is the failed deployments divided by all deployments. The deployments count is the query `round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))`, which counts the syncs that applied a change. Save this as `prometheusrule-dora-failures.yaml`. It holds two recording rules: the failed deployments and the ratio.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: dora-failures
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: dora-failures
      rules:
        - record: dora:failed_deployments:count6h
          expr: sum(changes((max by (name) (argocd_app_info{name="scout",health_status="Degraded"}) or max by (name) (argocd_app_info{name="scout"}) * 0)[6h:15s])) / 2
        - record: dora:change_failure_rate:ratio6h
          expr: dora:failed_deployments:count6h / round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))
```

Apply it:

```sh
kubectl apply -f prometheusrule-dora-failures.yaml
```

The rule reaches Prometheus after about a minute. Then check the ratio:

```sh
promql 'dora:change_failure_rate:ratio6h'
```

```text
{"metric":{"__name__":"dora:change_failure_rate:ratio6h"},"value":"0.2222222222222222"}
```

The change failure rate is `0.22`: two failures out of nine counted deployments. The count is nine and not ten because `increase()` sees the counter grow from `1` to `10`, and it has no sample at `0`. If a scrape was late and the counter started at `2`, the count is eight and the rate is `0.25`. Both values are correct for the samples Prometheus holds, so read the rate as about `0.2` to `0.25`. A rate near `0.33` or higher means a third deployment went `Degraded`, and that is a different problem: the seed history has exactly two bad commits. If the query returns nothing, wait another minute.

## Limits of the estimate

The seeded history has two complete, observed degraded episodes and no unrelated incidents. Outside this fixture, an episode can cross the query boundary, a scrape can miss a transition, or a runtime incident can degrade the service without a deployment. Several failed changes can also occur during one degraded episode. Treat `changes() / 2` as a teaching estimate under these assumptions; use deployment and incident records for a defensible change failure rate.

## Common pitfalls

> [!WARNING]
> - **Counting only `phase=~"Failed|Error"`.** Sync operations can fail on application errors or hooks. A successfully applied change can also leave an unhealthy workload. This fixture has successful syncs and two subsequent degraded episodes.
> - **Running `changes()` on the bare `Degraded` series.** The series exists only while the Application is degraded, so there is no flip to count. Build the always-present flag with `or ... * 0`.
> - **Skipping `max by (name)` before `or`.** Without it the `or` branch keeps one series for each health and sync status combination, and the result has several series instead of one.
> - **Treating health transitions as a universal failure count.** Division by two assumes complete sampled episodes with healthy values at both window boundaries. Correlate health incidents with deployment records before treating them as failed changes.
> - **A hard-coded number.** A rule such as `vector(2)` shows the right value today and the wrong one after the next failure.

## Your mission: Repair The Change Failure Rate Rule

The platform team measures the delivery of the workload `scout` with DORA (DevOps Research and Assessment) metrics. Argo CD, a GitOps controller, deploys `scout` into the namespace `starfleet` from the Application `scout` in the namespace `argocd`. Prometheus scrapes the Argo CD application controller. It has already deployed `scout` ten times, and two of those deployments used an image tag that does not exist.

This independent lab has 3 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-040-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-10/labs/lab-01
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-040/module-10/labs/lab-01
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-040-01
astrona start ats-020-playground-040-01
```

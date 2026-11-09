# Scale A Workload From A Queue Metric

The lab starts with both `scout` and `probe` already scraped. Each exposes `starfleet_queue_items`, a gauge that represents queued work. Compare all selected workloads before choosing which Deployment to scale.

Use the dedicated raw-Prometheus lab for these commands. Its discovery configuration is already correct, so no previous lab is required.

<!-- astrona:playground:renew -->

```sh
astrona stop ats-020-playground-010-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-10/labs/lab-03
kubectl -n monitoring port-forward service/prometheus-raw 9090:9090
```

Keep the port-forward in a separate terminal. First confirm that every ready `scout` and `probe` pod has a healthy target:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/targets?state=active' | jq '.data.activeTargets[] | {labels, health}'
```

## Compare the workload totals


Prometheus Query Language (PromQL) selects metrics and calculates results.
A time series is one metric name and label set with samples collected over
time. The fixture exposes `starfleet_queue_items`, a gauge whose value can
rise or fall. Run this query against the forwarded Service:

```sh
curl -fsSG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=sum by (deployment) (starfleet_queue_items{job="starfleet-pods",namespace="starfleet"})' | jq '.data.result'
```

`sum by (deployment)` adds the Pod values for each Deployment, keeping only
the grouping label. Read the Deployment name in `metric.deployment` and
compare the numbers in `value[1]`. Wait until both selected workloads appear;
a missing workload is not a zero queue. `shuttle` is outside this query's
selected population even though its fixture reports a larger queue.

The fixture assigns `probe` the larger per-Pod queue. After confirming that
its total is highest, add replicas:

```sh
kubectl -n starfleet scale deployment probe --replicas=3
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet get deployments scout probe shuttle
```

Look for three ready `probe` replicas and one ready replica on each other
Deployment. This synthetic gauge stays fixed per Pod; it teaches choosing an
action from a query, not a real queue draining model. In a real service,
verify that extra replicas can share the work, then measure the effect.


## Common pitfalls

> [!WARNING]
> - Missing samples do not mean a queue is empty.
> - Keep excluded workloads out of the ranking.
> - This fixture repeats a fixed gauge per pod; it does not model a queue draining after scaling.
> - Verify the new replica count and target coverage after the rollout.

## Your mission: Scale From A Queue Metric

Both metric workloads are already scraped. Use their queue gauges to decide which Deployment needs more replicas.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Use the lab started above.

Submit after verifying the result:

```sh
astrona submit -c sections/section-010/module-10/labs/lab-03
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-010-01-03
astrona start ats-020-playground-010-01
```

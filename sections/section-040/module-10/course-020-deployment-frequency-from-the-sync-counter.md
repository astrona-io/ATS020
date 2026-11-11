# Deployment Frequency From The Sync Counter

Argo CD counts sync operations. Select successful operations for `scout`, calculate their increase over the observation window, and record the count. Successful application of manifests does not guarantee that the resulting workload is healthy.

## The sync counter

Prometheus scrapes the Argo CD application controller, so the counter from the metrics page is also a time series in Prometheus. A time series is one metric name with one set of label values and a value stored at each scrape. Open a second terminal and leave a port-forward to Prometheus running. The Service `kps-prometheus` serves the Prometheus web interface and HTTP API on port `9090`:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Prometheus has an HTTP API for queries. This helper sends one PromQL query to it and prints one line per result series. It removes the labels that every Argo CD series shares, to keep the lines short:

```sh
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.container, .endpoint, .instance, .job, .pod, .service, .exported_namespace, .namespace, .dest_server, .dry_run, .project)), value: .value[1]}'
}
```

Query the counter for the Application `scout`:

```sh
promql 'argocd_app_sync_total{name="scout"}'
```

```text
{"metric":{"__name__":"argocd_app_sync_total","name":"scout","phase":"Succeeded"},"value":"10"}
```

There is one series, with `phase="Succeeded"`. The `phase` label says how the sync operation ended. Argo CD records `Succeeded` when it applied the manifests to the cluster without an error. Sync operations can also fail on invalid manifests or failed hooks; their phase is separate from the later health of the application. The counter reads `10`, the number of deployments in the Application history.

## Count the deployments in a window

A counter only goes up, so its raw value says little. The question is how many syncs happened in a time window. The PromQL function `increase()` answers it: it returns how much a counter grew over a range. Ask for the last 6 hours, which is all the data the playground Prometheus keeps:

```sh
promql 'increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])'
```

```text
{"metric":{"name":"scout","phase":"Succeeded"},"value":"9.092066666666666"}
```

The result is `9.09`, not `10`. Two things cause it. First, the series starts when Prometheus first sees it, with a value of `1` after the first sync, so Prometheus sees growth from `1` to `10`, which is `9`. It has no earlier sample at `0`. Second, `increase()` extrapolates the growth to the edges of the window, which adds a small fraction. The value also changes a little each time you run the query, because the window moves. Your number can differ from this output: `increase()` works only with the samples Prometheus holds. If the first scrape happened after the second sync, the first sample would be `2` and the result would be about `8`. The playground waits for a scrape after every sync, so expect a value from `9` to `9.5` here.

For a count of whole events, wrap the result in `round()`. Add `sum()` to remove the labels. Without the `name` filter, `sum()` would also add the deployments of every Application into one number:

```sh
promql 'round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))'
```

```text
{"metric":{},"value":"9"}
```

The result is `9` deployments in the window. It is one lower than the counter, for the reason above. Treat the number as `9`, give or take one, and not as an exact count. In a real platform the counter has existed for weeks, so the first sample no longer matters. The same query with `[7d]` then gives deployments per week, and `[1d]` gives deployments per day.

The `phase="Succeeded"` filter matters. Without it, the query counts syncs that failed to apply, which are attempts and not deployments.

## Store the result as a recording rule

A recording rule is a PromQL expression that Prometheus runs on a schedule and stores as a new time series. A dashboard that reads the stored series does not run the heavy query each time. The Prometheus Operator reads recording rules from a PrometheusRule resource. The Prometheus in the playground selects only PrometheusRules that carry the label `release: kps`. Save this as `prometheusrule-dora-deployments.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: dora-deployments
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: dora-deployments
      rules:
        - record: dora:deployments:increase6h
          expr: round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))
```

Apply it:

```sh
kubectl apply -f prometheusrule-dora-deployments.yaml
```

The Prometheus Operator turns the resource into a rules file, and the running Prometheus reads it about a minute later. Then check the stored series:

```sh
promql 'dora:deployments:increase6h'
```

```text
{"metric":{"__name__":"dora:deployments:increase6h"},"value":"9"}
```

The new series `dora:deployments:increase6h` holds `9`. If the query returns nothing, wait another minute and run it again. The name follows the convention `level:metric:operations`: the part before the first colon says what the series aggregates, the middle says which metric it comes from, and the last says the operation.

## Common pitfalls

> [!WARNING]
> - **Reading the raw counter as a frequency.** `argocd_app_sync_total` is a total since the controller started. Use `increase()` over a window.
> - **Expecting a whole number from `increase()`.** It extrapolates. Use `round()` when you count events.
> - **Leaving out `phase="Succeeded"`.** The count then includes syncs that failed to apply.
> - **A PrometheusRule without `release: kps`.** Prometheus does not select it, and the recording rule never runs.
> - **Querying a window longer than the retention.** The playground Prometheus keeps 6 hours of data, so `[7d]` returns the data of the last 6 hours only.

## Your mission: Measure Deployment Frequency

Argo CD has synced ten revisions of `scout`. The recording rule selects failed sync operations, so it does not count the deployments.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-040-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-10/labs/lab-02
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-040/module-10/labs/lab-02
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-040-01-02
astrona start ats-020-playground-040-01
```

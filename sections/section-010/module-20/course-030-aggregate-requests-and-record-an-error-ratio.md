# Aggregate Requests And Record An Error Ratio

A rate per pod and per status code is too detailed for most questions. "How many requests per second does each namespace serve?" needs one number per namespace, and "what share of requests fail?" needs one number in total. Aggregate request rates into an error ratio, then store that expression as a recording rule for alerts and dashboards.

## Sum by and sum without

An **aggregation operator** combines many series into fewer. `sum`, `avg`, `min`, `max` and `count` work the same way, and each one takes a clause that says which labels survive. `by (...)` keeps only the labels you list; `without (...)` keeps every label except the ones you list.

Start with one rate per namespace:

Forward `svc/kps-prometheus` on port `9090` in another terminal. In your working terminal, define the helper before running the queries:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

```sh
promql() {
  curl -fsSG http://127.0.0.1:9090/api/v1/query --data-urlencode "query=$1" |
    jq -r '.data.result[] | "\(.metric | del(.__name__) | to_entries | map("\(.key)=\(.value)") | join(","))\t\(.value[1])"'
}
```

```sh
promql 'sum by (namespace) (rate(http_requests_total[5m]))'
```

You should see something like:

```text
namespace=starfleet	1.501754385964912
namespace=outpost	1.0596491228070175
```

Every series of `http_requests_total`, from every pod and every status, was turned into a rate and then added up per namespace. `starfleet` serves more, because the traffic loop sends it extra failing and slow requests. A `sum` with no clause would return one number for everything.

Now split the `starfleet` traffic by status code:

```sh
promql 'sum by (status) (rate(http_requests_total{namespace="starfleet"}[5m]))'
```

You should see something like:

```text
status=200	1.326315789473684
status=500	0.17543859649122806
```

The same result with `without` keeps more context. Remove only the labels that differ per pod:

```sh
promql 'sum without (instance, pod) (rate(http_requests_total{namespace="starfleet"}[5m]))'
```

You should see something like:

```text
container=scout,endpoint=http,job=scout,namespace=starfleet,service=scout,status=200	1.326315789473684
container=scout,endpoint=http,job=scout,namespace=starfleet,service=scout,status=500	0.17543859649122806
```

The values are the same, but the result still carries `job`, `namespace` and `service`. Use `by` when you know exactly which labels you want in the answer, and `without` when you want to drop only the per-pod detail and keep everything else for a later filter or a dashboard legend.

## The error ratio

The **error ratio** is the share of requests that failed: failed requests per second divided by all requests per second. Both sides are sums of rates over the same window and the same selector, apart from the status filter:

```sh
promql 'sum(rate(http_requests_total{namespace="starfleet", status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet"}[5m]))'
```

You should see something like:

```text
	0.11682242990654207
```

About 11.7% of the `starfleet` `scout` requests fail. The line has no labels, which is why it starts with a tab: both `sum`s dropped every label, so the division returns one plain number. That is what you want for an alert threshold or a service level.

Division in PromQL matches series by their labels. If you write `sum by (namespace)` on one side and plain `sum` on the other, the label sets do not match and the result is empty. Keep the same `by (...)` on both sides, for example `sum by (namespace) (...) / sum by (namespace) (...)` for one ratio per namespace.

A recording rule saves this expression under a metric name. Use `sum(rate(...))` in both numerator and denominator so pods with different traffic volumes contribute in proportion to their requests. Keep the same namespace and container filters on both sides. A rule that divides one pod's errors by another population's requests can return a plausible but incorrect ratio.


## Store a query as a recording rule

A PrometheusRule is a Kubernetes resource that the Prometheus Operator reads. Its `release: kps` label makes this server select it. The `record` field names the new series; `expr` contains the query to evaluate. Save this as `scout-queries.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-queries
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: scout-queries
      rules:
        - record: scout:error_ratio:rate5m
          expr: sum(rate(http_requests_total{namespace="starfleet",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet"}[5m]))
```

Apply it and inspect the loaded rule after reconciliation:

```sh
kubectl apply -f scout-queries.yaml
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/rules | jq '.data.groups[].rules[] | select(.name == "scout:error_ratio:rate5m")'
promql 'scout:error_ratio:rate5m'
```

The rule must have healthy evaluation and return the same population as the direct query. In the independent lab, the resource already has two rules; edit only the assigned expression and retain the other one.

## Common pitfalls

> [!WARNING]
> - Do not average per-pod error ratios; aggregate request rates before dividing.
> - Apply `rate()` before `sum()` so counter resets are handled per series.
> - An empty result is not an error ratio of zero. Check labels and available samples.

## Your mission: Repair An Error Ratio Recording Rule

The recording rule `scout:error_ratio:rate5m` in `monitoring/scout-queries` returns the wrong result. The other recording rule is already correct.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-010-02
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-20/labs/lab-02
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-010/module-20/labs/lab-02
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-010-02
astrona start ats-020-playground-010-02
```

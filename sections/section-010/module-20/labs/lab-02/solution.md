# Solution Walkthrough

Inspect the two recorded series, repair their expressions and compare their
values with the source metrics. A recording rule evaluates a Prometheus Query
Language (PromQL) expression and stores its result as a new time series. The
Prometheus Operator loads these rules from a PrometheusRule resource.

| Goal | Expression detail | Evidence |
| --- | --- | --- |
| Keep the rules selected | `release: kps` on `scout-queries` | `rules-intact` |
| Compute the error ratio | Divide failing request rate by total request rate | One series matching the counter query |
| Compute combined p95 latency | Sum bucket rates by `le` before `histogram_quantile()` | One series matching the histogram query |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-20/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

Before making changes, expect `rules-intact` to pass: both rules already
exist and read the required metrics. Expect `error-ratio` and `p95-latency`
to fail because their recorded results are wrong.

## Step 1: Inspect the rules and their results

Forward Prometheus in another terminal and leave it running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

In your working terminal, inspect the resource and query each recorded series
through the application programming interface (API):

```sh
kubectl -n monitoring get prometheusrule scout-queries -o yaml
curl -fsSG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=scout:error_ratio:rate5m' | jq '.data.result'
curl -fsSG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=scout:request_duration_seconds:p95_5m' | jq '.data.result'
```

Each result has labels in `metric` and a timestamp and value in `value`.
Look for a small error ratio and several latency results. The ratio divides
requests per second by a counter's accumulated total, so its units do not
match. The latency expression keeps separate label combinations instead of
combining the workload's histogram buckets.

No check changes yet; the watch terminal should still show only
`rules-intact` passing.

## Step 2: Repair both recording rules

Save this as `prometheusrule-scout-queries.yaml`:

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
        - record: scout:request_duration_seconds:p95_5m
          expr: histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m])))
```

`apiVersion` and `kind` select the resource type. The name and namespace update
the existing resource, and `release: kps` keeps it selected by the operator.
`groups` holds the group, and each `record` keeps the required series name.
Each `expr` defines the value Prometheus records.

The first expression applies `rate()` over five minutes to both counters
before summing them. The matcher `status=~"5.."` selects failing status codes.
Both sides select `namespace="starfleet"`, so traffic to `outpost` does not
affect the ratio. Each sum removes the remaining labels and returns one
series.

The second expression calculates the 95th percentile, or p95: the estimated
duration below which 95% of requests fall. A histogram counts observations
in buckets, and the `le` label holds each bucket's upper bound. `sum by (le)`
combines bucket rates across pods and request labels while keeping those
bounds for `histogram_quantile()`. The argument `0.95` selects the percentile;
the duration itself still comes from the metrics.

Apply it:

```sh
kubectl apply -f prometheusrule-scout-queries.yaml
```

Then check the result:

```sh
kubectl -n monitoring get prometheusrule scout-queries -o yaml
```

Confirm both expressions, both names and the `release: kps` label. Allow about
a minute for the changed rules to reach Prometheus, then allow a rule
evaluation. Old latency series can remain visible briefly while they become
stale.

**Run the check:** the watch terminal keeps `rules-intact` passing. After
propagation and evaluation, it should also show `error-ratio` and
`p95-latency` passing.

## Step 3: Compare recorded values with the source metrics

Query the ratio and its source expression together:

```sh
curl -fsSG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=scout:error_ratio:rate5m' | jq '.data.result'
curl -fsSG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(http_requests_total{namespace="starfleet",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet"}[5m]))' | jq '.data.result'
```

Both responses must contain one result. Compare the numeric strings in
`value[1]`. The grader accepts an absolute difference below `0.03` and requires
the source ratio to be between `0.05` and `0.25`. Do not replace the expression
with a number to meet that range.

Do the same for latency:

```sh
curl -fsSG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=scout:request_duration_seconds:p95_5m' | jq '.data.result'
curl -fsSG http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="starfleet"}[5m])))' | jq '.data.result'
```

Both responses must again contain one result. The grader requires the source
p95 to exceed `0.5` seconds and the recorded value to differ by less than 25%
of that source value. A recorded sample and a fresh query can differ slightly
because they evaluate at different times.

**Run the check:** the watch terminal should show `rules-intact`, `error-ratio`
and `p95-latency` passing. If data is missing just after startup, allow more
scrapes and rule evaluations, then query again.

## Step 4: Submit

Once the watch terminal shows all three checks passing, press Ctrl-C to stop
the watch and submit once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-20/labs/lab-02
```

## If a check stays red

- **`rules-intact`: the object or a rule is missing.** Keep the resource in
  `monitoring`, keep `release: kps` and keep both recording rule names exactly.
  Each expression must read its source metric and must not use `vector()` or
  `scalar()` to supply a value.
- **`error-ratio`: the value is too small.** Apply `rate()` to the denominator
  as well as the numerator, with the same five-minute window and namespace.
- **`p95-latency`: there is more than one series.** Combine bucket rates with
  `sum by (le)` before calling `histogram_quantile()`. Keeping other labels
  creates separate results; dropping `le` loses the bucket bounds.
- **Either value check still sees the old result.** Confirm the resource has
  the new expressions, then allow configuration propagation and evaluation.
  Keep the traffic running so the grader can compare against live metrics.

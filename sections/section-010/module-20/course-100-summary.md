# Summary

Every dashboard, alert and service level starts as a PromQL query, and each part of a query changes its meaning. This module built the queries an operator needs most, from selecting series to reading the answer in a script.

## What you learned

A time series is one metric name with one exact set of labels. A selector picks series with label matchers: `=` and `!=` for exact values, `=~` and `!~` for regular expressions that must match the whole value. Without a time range a selector returns an instant vector, one latest value per series; with `[5m]` it returns a range vector, every sample in the window, which functions such as `rate()` take as input.

Counters only go up and reset on restart, gauges go up and down, and histograms store counters per bucket in `_bucket`, `_sum` and `_count`. `rate()` turns a counter's range into an average per-second increase and handles resets; `increase()` gives the growth over the whole window. Both are extrapolated estimates. `rate()` on a gauge returns meaningless numbers with only an `infos` note, so gauges use their value or functions such as `avg_over_time()`.

Aggregation operators combine series: `sum by (...)` keeps only the listed labels, `sum without (...)` drops only the listed ones. The error ratio is the sum of failed-request rates divided by the sum of all request rates, with the same labels on both sides. A latency percentile comes from `histogram_quantile()` over the summed rates of the `_bucket` series with `le` kept, and its precision is limited by the bucket bounds.

The HTTP API answers on `/api/v1/query` with a `status`, a `resultType` and a list of results whose values are strings. An empty list is still a success, so scripts must check that a value exists, and `jq -e` turns a comparison into an exit code. The key facts to remember are these:

- Select the series, turn counters into rates, then aggregate to the labels you need.
- Use `[5m]` or at least four scrape intervals inside `rate()`.
- Keep `le` when you sum buckets for `histogram_quantile()`.
- Read the API value as a string and convert it before you compare it.

<!-- astrona:playground:destroy -->

# Question

Solve this question on: `terminal`

The `scout` workload in the namespace `starfleet` serves an HTTP API. The pod `shuttle` sends it steady traffic all the time, including requests that fail with status `500` and requests that take one second. Prometheus in the namespace `monitoring` scrapes `scout`. Prometheus is the Service `kps-prometheus` on port `9090`.

The platform team keeps two recording rules for `scout` in the PrometheusRule `scout-queries` in the namespace `monitoring`. A recording rule is a PromQL expression that Prometheus runs on a schedule and stores as a new time series. The rule `scout:error_ratio:rate5m` should hold the share of requests that fail. The rule `scout:request_duration_seconds:p95_5m` should hold the 95th percentile of the request duration. Both series hold wrong values. The team asks you to fix them.

## Task

1. Query the two recorded series in Prometheus and compare them with what you expect from the traffic. The error ratio is much too small, and the latency query returns many series instead of one.
2. Fix the expression of `scout:error_ratio:rate5m`. It must be the failing requests per second (status `5xx`) divided by all requests per second, for `scout` in the namespace `starfleet`, over a `5m` window.
3. Fix the expression of `scout:request_duration_seconds:p95_5m`. It must be the 95th percentile of the request duration of `scout` in the namespace `starfleet`, over a `5m` window, as one series.
4. Prove the fix. Each recorded series must return exactly one result with a value that matches the real traffic.

## Constraints

- Keep the PrometheusRule `scout-queries` in the namespace `monitoring`, with the label `release: kps`.
- Keep both recording rules and their names.
- Do not type a number into an expression. Do not use `vector()` or `scalar()`. The values must come from the metrics `http_requests_total` and `http_request_duration_seconds_bucket`.
- Do not delete the PrometheusRule or any of its rules.

## How the answer is checked

The grader runs three checks. The first checks that the PrometheusRule and its two rules are still there, that each rule reads the real metric, and that no expression types a number. The second reads `scout:error_ratio:rate5m` from Prometheus, needs exactly one series, and compares its value with the real error ratio that the grader computes from the counter. The third does the same for the 95th percentile and the histogram. A changed rule reaches Prometheus after about a minute, so the grader retries for a few minutes.

Hint: reach Prometheus with `kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090`.

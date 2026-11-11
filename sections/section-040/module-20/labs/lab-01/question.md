# Question

Solve this question on: `terminal`

The platform team promises an availability SLO (service level objective) of 99 percent for the workload `scout` in the namespace `starfleet`. A burn-rate alert must tell the team when `scout` spends its 30-day error budget more than twice as fast as the SLO allows. A traffic loop makes about 5 percent of the requests to `scout` fail with status `500`, so the alert must fire. It does not.

The team stores the alert and two recording rules in the PrometheusRule `scout-slo` in the namespace `monitoring`. The rules `scout:error_ratio:rate5m` and `scout:error_ratio:rate1h` store the share of failed requests over five minutes and over one hour. The alert `ScoutErrorBudgetBurn` reads both. Prometheus shows no alert and no error ratio. The team asks you to fix it.

## Tasks

1. Find out why the alert `ScoutErrorBudgetBurn` is not active. Read the rules in the PrometheusRule `scout-slo` and run their expressions in Prometheus, one part at a time.
2. Change the PrometheusRule so that the recording rules return the real error ratio of `scout`.
3. Prove the fix. Prometheus must return the error ratio for both recording rules, and the alert `ScoutErrorBudgetBurn` must reach the state `firing`.

## Constraints

- Keep the PrometheusRule `scout-slo` in the namespace `monitoring`, with the label `release: kps`.
- Keep both recording rules and the alert, with their names.
- Keep both windows in the alert (`5m` and `1h`), joined with `and`, and keep a `for:` of at most `5m`.
- Do not set the threshold of the alert to zero.
- Do not type the error ratio into a rule. Both ratios must come from the counter `http_requests_total`.
- Do not delete the PrometheusRule or any of its rules.

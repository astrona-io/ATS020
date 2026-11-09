# Question

Solve this question on: `terminal`

Traffic to `scout` includes status `500` responses. Its alerting rule is missing; the receiver route already works.

Allow 10–15 minutes for the tasks. Cluster startup and telemetry collection add time.

## Tasks

1. Inspect the Prometheus rule selectors and the `scout` request counter.
2. Create `starfleet/scout-errors` with the specified rule and `release: kps`.
3. Confirm that `ScoutErrorRate` is loaded and healthy in Prometheus.
4. Wait for the alert to fire with `namespace=starfleet`, `team=scout` and `severity=warning`.

## Constraints

Create `ScoutErrorRate` with `sum by (namespace) (rate(http_requests_total{job="scout",namespace="starfleet",status="500"}[1m])) > 0.1`, `for: 1m`, and labels `team: scout` and `severity: warning`. Keep the Prometheus selectors unchanged.

## Verification

The grader checks the running system. Submit after the rollout and any telemetry updates have finished.

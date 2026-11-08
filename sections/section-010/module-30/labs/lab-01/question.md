# Question

Solve this question on: `terminal`

## Scenario

The `scout` team gets no notification even though its workload in `starfleet`
returns errors. Prometheus already scrapes both `scout` Pods. The
`scout-routing` AlertmanagerConfig matches the wrong team, and the team has
not installed its alerting rule. A separate alert, `ProbeMaintenance`, is
already firing for a planned maintenance window.

The trimmed monitoring stack runs in `monitoring`. The webhook receiver is
`http://alert-receiver.monitoring:8080/`, and its Deployment is
`alert-receiver`. The terminal has `kubectl`, `curl` and `jq`. The Alertmanager
container has `amtool`.

## Tasks

1. **Load the team's rule.** Create a PrometheusRule named `scout-errors` in
   `starfleet`, with `metadata.labels.release: kps`. Add one alert named
   `ScoutErrorRate` using this expression (spacing may differ):

   ```promql
   sum by (namespace) (rate(http_requests_total{job="scout",namespace="starfleet",status="500"}[1m])) > 0.1
   ```

   This metric is the request counter; the expression alerts when the total
   rate of status `500` requests exceeds `0.1` requests per second. Use
   `for: 1m` and labels `team: scout` and `severity: warning`. The rule must
   appear healthy in the running Prometheus rules API, then fire with
   `namespace: starfleet`. Keep the Prometheus resource's rule selectors
   unchanged: `ruleSelector.matchLabels.release: kps` and
   `ruleNamespaceSelector: {}`.

2. **Deliver the alert.** Fix the AlertmanagerConfig `scout-routing` in
   `starfleet` to route `team="scout"` alerts to its receiver
   `scout-webhook`, using the existing webhook URL. In the Alertmanager API,
   `ScoutErrorRate` must be active and assigned to
   `starfleet/scout-routing/scout-webhook`. The receiver must log a firing
   notification with `namespace=starfleet` and `severity=warning`.

3. **Silence the maintenance alert.** Create an active silence lasting
   exactly 30 minutes, with exactly these two equality matchers:
   `alertname="ProbeMaintenance"` and `namespace="starfleet"`. Set the author
   to `platform` and the comment to `probe maintenance window`. The silence
   must suppress that alert in Alertmanager while it remains firing in
   Prometheus. You may use the Alertmanager UI or `amtool`; the API must show
   the same result.

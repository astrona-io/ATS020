# Burn-Rate Alerts With Two Windows

An SLI below its target tells you the service is in trouble, but it does not say how urgent the trouble is. A service at 98.9 percent for a day and a service at 50 percent for five minutes both miss a 99 percent target. The first one slowly drains the error budget. The second one drains it almost at once. This part measures how fast the budget drains and turns that speed into an alert.

## Burn rate is the speed of spending

The burn rate is the error ratio divided by the error budget. A burn rate of `1` means the service spends its budget exactly as fast as the SLO window allows, so the budget lasts the whole window. A burn rate of `5` means the budget is gone in one fifth of the window.

For a 30-day SLO window, the days until the budget is gone are `30` divided by the burn rate. The window of the SLO and the time range of the query are two different things. The query looks at the last few minutes or hours, and the result tells you how long the 30-day budget would last if the errors continued at that rate.

Open a port-forward to Prometheus and define the helper that runs a query:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 &
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.endpoint, .instance, .job, .service, .namespace)), value: .value[1]}'
}
```

The burn rate of `scout` over five minutes is the share of requests with a `5xx` status, divided by the budget `1 - 0.99`:

```sh
promql 'sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[5m])) / (1 - 0.99)'
```

```text
{"metric":{},"value":"4.9572982143919"}
```

The burn rate is about `5`. The error ratio is `0.05` and the budget is `0.01`. Now divide the 30 days by the burn rate over one hour:

```sh
promql '30 / (sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[1h])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[1h])) / (1 - 0.99))'
```

```text
{"metric":{},"value":"6.051783675552806"}
```

If `scout` keeps failing at this rate, the 30-day error budget is gone after about 6 days. That is a problem worth a ticket, but not a page at night.

## Two windows in one alert

An alert on one window has a trade-off. A short window, such as five minutes, reacts fast, but one bad minute can trigger it. A long window, such as one hour, ignores short spikes, but it keeps firing for a long time after the errors stop, because the old errors stay in the window.

A multi-window alert uses both and requires both to be true. The long window proves that the burn is not a spike. The short window proves that the burn is still going on, so the alert stops soon after the errors stop. The threshold is a burn rate. Common production values are `14.4` for a page (2 percent of a 30-day budget in one hour) and `6` or lower for a ticket. This module uses `2` so that the alert fires on the playground traffic, which burns at about `5`.

Save this as `prometheusrule-scout-burn.yaml`. It stores the two burn rates as recording rules, a rule that runs a PromQL expression on a schedule and stores the result as a time series. It adds an alerting rule, which fires while its expression returns a result for longer than `for:`.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-burn
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: scout-burn
      rules:
        - record: scout:burn_rate:rate5m
          expr: sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[5m])) / (1 - 0.99)
        - record: scout:burn_rate:rate1h
          expr: sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[1h])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[1h])) / (1 - 0.99)
        - alert: ScoutErrorBudgetBurn
          expr: scout:burn_rate:rate5m > 2 and scout:burn_rate:rate1h > 2
          for: 2m
          labels:
            severity: ticket
            service: scout
          annotations:
            summary: scout spends its 30-day error budget more than twice as fast as the SLO allows
```

Apply it:

```sh
kubectl apply -f prometheusrule-scout-burn.yaml
```

The operator mounts the rule into Prometheus, which takes about a minute. Then check the stored burn rate and the alert. Prometheus holds the alert in the state `pending` while the expression is true but `for:` has not passed yet:

```sh
promql 'scout:burn_rate:rate5m'
curl -s http://127.0.0.1:9090/api/v1/alerts | jq -c '.data.alerts[] | {alertname: .labels.alertname, severity: .labels.severity, state}'
```

```text
{"metric":{"__name__":"scout:burn_rate:rate5m"},"value":"4.957570343903524"}
{"alertname":"ScoutErrorBudgetBurn","severity":"ticket","state":"pending"}
```

After the two minutes of `for:`, run the second command again. The state changes to `firing`:

```text
{"alertname":"ScoutErrorBudgetBurn","severity":"ticket","state":"firing"}
```

This playground has no Alertmanager, so nothing receives a notification. Prometheus still evaluates the rule and keeps the state, and the endpoint `/api/v1/alerts` shows it. In a real platform, Alertmanager takes the firing alert and sends it to a receiver.

You can now measure the burn rate, estimate how long the budget lasts and alert on both a short and a long window. The alert depends on every selector in the expression being right. If one selector matches nothing, the expression returns no data and the alert never fires, with no error to show for it. The mission below practises exactly that.

## Common pitfalls

> [!WARNING]
> - **A regex that matches no status.** `status=~"5xx"` looks for the literal text `5xx`. It matches nothing, the ratio has no data and the alert stays silent. Use `5..`.
> - **One window only.** A single 5-minute window pages on every spike. A single 1-hour window keeps firing long after the incident ends. Use both with `and`.
> - **A threshold of zero.** `> 0` fires on a single failed request. The threshold is a burn rate, so choose a value such as `2`, `6` or `14.4`.
> - **Missing `for:`.** Without `for:`, the alert fires at the first evaluation where the expression is true. Keep a short wait so that one bad evaluation does not send a notification.
> - **Waiting too little.** A new rule needs about a minute to reach Prometheus, and the alert needs the `for:` time on top. Check again before you decide that it does not work.

## Your mission: Fix The Burn-Rate Alert

You can now write a multi-window burn-rate alert for an SLO and read its state in Prometheus. The mission gives you a PrometheusRule whose alert never fires, although `scout` fails 5 percent of its requests. Find out why and fix it without weakening the alert.

Pause the playground, then start the lab:

```sh
astrona stop ats-020-playground-040-02
```

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-20/labs/lab-01
```

The task is on the next page. When you have fixed the rule, grade your work:

```sh
astrona submit -c sections/section-040/module-20/labs/lab-01
```

When the lab is done, remove it and start the playground again:

```sh
astrona destroy ats-020-lab-040-02
astrona start ats-020-playground-040-02
```

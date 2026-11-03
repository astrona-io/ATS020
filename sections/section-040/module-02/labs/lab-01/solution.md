# Solution

This walkthrough fixes the PrometheusRule `scout-slo` step by step. After each step you can run `astrona submit -c sections/section-040/module-02/labs/lab-01` to see which checks pass. Values in the output differ a little in your cluster.

## Step 1: See that the alert is not active

Open a port-forward to Prometheus and define a helper that runs a query:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090 &
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.endpoint, .instance, .job, .service, .namespace)), value: .value[1]}'
}
```

List the alerts that Prometheus knows about:

```sh
curl -s http://127.0.0.1:9090/api/v1/alerts | jq -c '.data.alerts'
```

```text
[]
```

The list is empty. The alert is not `pending` and not `firing`. The rule list shows that Prometheus loaded the three rules and that they evaluate without an error (`health` is `ok`). So the rule is valid but its expression returns nothing:

```sh
kubectl -n monitoring get prometheusrule scout-slo -o jsonpath='{range .spec.groups[0].rules[*]}{.record}{.alert}{"\n"}{end}'
promql 'scout:error_ratio:rate5m'
```

```text
scout:error_ratio:rate5m
scout:error_ratio:rate1h
ScoutErrorBudgetBurn
```

The second command prints nothing. The recording rule has no data, so the alert, which reads it, has nothing to compare.

## Step 2: Run the expression one part at a time

The recording rule divides the rate of failed requests by the rate of all requests. Run the rate of all requests for each status first:

```sh
promql 'sum by (status) (rate(http_requests_total{namespace="starfleet",container="scout"}[5m]))'
```

```text
{"metric":{"status":"200"},"value":"25.039651931623933"}
{"metric":{"status":"500"},"value":"1.3059581196581198"}
```

The status `500` exists and `scout` serves about 1.3 failed requests each second. The rule selects failed requests with `status=~"5xx"`. Run that selector alone:

```sh
promql 'sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5xx"}[5m]))'
```

It prints nothing. Prometheus anchors a regular expression at both ends, and `5xx` is literal text: the characters `5`, `x`, `x`. No status looks like that. The pattern `5..` matches a `5` followed by any two characters:

```sh
promql 'sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[5m]))'
```

```text
{"metric":{},"value":"1.3061061452991454"}
```

## Step 3: Fix both recording rules

Both recording rules use the wrong selector, one for the 5 minute window and one for the 1 hour window. Save this as `prometheusrule-scout-slo.yaml`. Only the two `status=~` selectors changed:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-slo
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: scout-slo
      rules:
        - record: scout:error_ratio:rate5m
          expr: sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[5m]))
        - record: scout:error_ratio:rate1h
          expr: sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[1h])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[1h]))
        - alert: ScoutErrorBudgetBurn
          expr: scout:error_ratio:rate5m / (1 - 0.99) > 2 and scout:error_ratio:rate1h / (1 - 0.99) > 2
          for: 2m
          labels:
            severity: ticket
            service: scout
          annotations:
            summary: scout spends its 30-day error budget more than twice as fast as the SLO allows
```

Apply it:

```sh
kubectl apply -f prometheusrule-scout-slo.yaml
```

The alert is not the fault. Its expression divides the error ratio by the budget `1 - 0.99` to get the burn rate and compares it with `2`, once for each window. Do not change it.

## Step 4: Prove the fix

The new rule reaches Prometheus after about a minute. Then read the two error ratios:

```sh
promql 'scout:error_ratio:rate5m'
promql 'scout:error_ratio:rate1h'
```

```text
{"metric":{"__name__":"scout:error_ratio:rate5m"},"value":"0.049577443284911746"}
{"metric":{"__name__":"scout:error_ratio:rate1h"},"value":"0.049577443284911746"}
```

The error ratio is about `0.05`, which is 5 percent. Divided by the budget `0.01`, the burn rate is about `5`, above the threshold `2` in both windows. The alert first goes to `pending` and, after the `for:` time of two minutes, to `firing`:

```sh
curl -s http://127.0.0.1:9090/api/v1/alerts | jq -c '.data.alerts[] | {alertname: .labels.alertname, state}'
```

```text
{"alertname":"ScoutErrorBudgetBurn","state":"pending"}
```

Run the command again after two minutes:

```text
{"alertname":"ScoutErrorBudgetBurn","state":"firing"}
```

Now run `astrona submit` again. All three checks pass.

## Why the plausible shortcuts fail

- **Deleting the alert or a recording rule.** The first check needs both recording rules and the alert.
- **Removing one window from the alert.** The first check needs `5m`, `1h` and `and` in the expression.
- **Setting the threshold to `> 0`.** The first check rejects a threshold of zero, because it fires on a single failed request.
- **Typing the ratio, for example `vector(0.05)`.** The second check needs `http_requests_total` in both recording rules and rejects `vector()`.
- **Fixing only one recording rule.** The second check reads both, and the alert needs both windows to be true.

# Recording And Alerting Rules

An alert is a PromQL query that Prometheus keeps running on its own. Before it can page anyone, the query must live somewhere Prometheus reads, under a name and with labels that later decide where it goes. This part writes a PrometheusRule for `scout`: a recording rule that stores its error ratio as a new series, and an alerting rule that fires when that ratio stays too high.

## Two kinds of rule

A **rule** is a PromQL expression that Prometheus evaluates on a fixed interval, without anyone asking. There are two kinds:

- A **recording rule** stores the result of its expression as a new time series under the name in `record`. Dashboards and alerts then read that cheap, precomputed series instead of running the full query again.
- An **alerting rule** raises an alert named in `alert` for every series its expression returns. The expression is usually a comparison, such as "error ratio greater than 5%", so it returns series only while the condition is true.

Rules live in **groups**. All rules in a group are evaluated in order, on the group's `interval`, so a recording rule can feed an alerting rule placed after it in the same group.

## Which rules Prometheus reads

A **PrometheusRule** is the Prometheus Operator's resource for rule groups. Like monitors, it is only read when the Prometheus resource's selector matches it. Check that selector first:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring get prometheus kps-prometheus -o yaml | grep -A3 -E "ruleSelector|ruleNamespaceSelector"
```

You should see:

```text
  ruleNamespaceSelector: {}
  ruleSelector:
    matchLabels:
      release: kps
  scrapeConfigNamespaceSelector: {}
```

The empty `ruleNamespaceSelector` matches every namespace, and `ruleSelector` only matches PrometheusRules with the label `release: kps`. The last line is the next field in the file.

## Write the rules

Save this as `prometheusrule-scout.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout
  namespace: starfleet
  labels:
    release: kps
spec:
  groups:
    - name: scout
      interval: 15s
      rules:
        - record: namespace:http_requests_error_ratio:rate1m
          expr: |
            sum by (namespace) (rate(http_requests_total{job="scout", status=~"5.."}[1m]))
            /
            sum by (namespace) (rate(http_requests_total{job="scout"}[1m]))
        - alert: ScoutHighErrorRatio
          expr: namespace:http_requests_error_ratio:rate1m > 0.05
          for: 1m
          labels:
            severity: warning
            team: starfleet
          annotations:
            summary: "scout in {{ $labels.namespace }} fails {{ $value | humanizePercentage }} of requests"
```

The recording rule's name follows the Prometheus convention `level:metric:operations`: the labels the result keeps (`namespace`), the metric it is based on, and what was done to it (`rate1m`). The name makes the series easy to find and says what it contains.

The alerting rule has four parts:

- `expr` is the condition. It reads the recorded series and returns it only where the value is above `0.05`, that is 5%.
- `for: 1m` is how long the condition must hold before the alert fires. A short spike that is gone after 30 seconds never notifies anyone.
- `labels` are added to the alert. `severity` and `team` are not special to Prometheus; Alertmanager uses them later to decide where the alert goes.
- `annotations` hold text for humans. `{{ $labels.namespace }}` and `{{ $value }}` are filled in when the alert fires, and `humanizePercentage` turns `0.43` into `43%`.

Apply it:

```sh
kubectl apply -f prometheusrule-scout.yaml
```

## Check that Prometheus loaded the rules

The operator puts the rules into a ConfigMap that is mounted into the Prometheus pod, so they take up to about a minute to arrive. Start a port-forward to Prometheus in a second terminal and leave it running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

After a minute, list the rules Prometheus has loaded, with their health and, for alerts, their state:

```sh
curl -s http://127.0.0.1:9090/api/v1/rules |
  jq -r '.data.groups[] | .name as $group | .rules[] | "\($group)\t\(.type)\t\(.name)\t\(.health)\t\(.state // "-")"'
```

You should see:

```text
scout	recording	namespace:http_requests_error_ratio:rate1m	ok	-
scout	alerting	ScoutHighErrorRatio	ok	inactive
```

Both rules are loaded and healthy, and the alert is `inactive` because its condition is false. If a rule is missing here, check the `release: kps` label; if its health is `err`, the rule has a PromQL error, and the API's `lastError` field says which. The page `http://127.0.0.1:9090/alerts` shows the same alert in a browser.

Now query the recorded series with the `promql` helper. Paste it into your first terminal if this terminal does not have it yet:

```sh
promql() {
  curl -s http://127.0.0.1:9090/api/v1/query --data-urlencode "query=$1" |
    jq -r '.data.result[] | "\(.metric | del(.__name__) | to_entries | map("\(.key)=\(.value)") | join(","))\t\(.value[1])"'
}
promql 'namespace:http_requests_error_ratio:rate1m'
```

It prints nothing, and that is correct. `scout` has never answered with a `5xx`, so the selector `status=~"5.."` finds no series, the top half of the division is empty, and an empty side makes the whole result empty. The ratio is not `0`; it does not exist. That is also why the alert is `inactive`: its expression returns nothing, which counts as "condition false".

You can now write recording and alerting rules in a PrometheusRule, get them picked up by the right label, and check that Prometheus loaded them. The alert has never fired, though. The open question is what happens between "the condition is true" and "someone is told".

## Common pitfalls

> [!WARNING]
> - **Leaving out the label `ruleSelector` matches.** The PrometheusRule is created, but Prometheus never loads it, and no error appears.
> - **Expecting a ratio to be `0` when nothing failed.** A ratio built from a series that does not exist is empty, not zero. Alerts on "error ratio too high" still work; alerts on "ratio below X" do not.
> - **Writing `for` as a delay you can skip.** Without `for`, a single bad evaluation fires the alert at once.
> - **Checking the rules right after `kubectl apply`.** The rules arrive through a mounted ConfigMap; give it about a minute.

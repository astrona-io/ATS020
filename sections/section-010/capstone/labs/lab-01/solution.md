# Solution

Solve this lab on `terminal`. The three objects have three independent faults. The ServiceMonitor `scout` has the wrong label and the wrong selector, so Prometheus has no target. The PrometheusRule `scout` matches a status that no request has and compares the ratio with `5` instead of `0.05`, and it waits ten minutes. The AlertmanagerConfig `frontier` routes on the wrong label and posts to the wrong port. Fix them in the order below, because each fix makes the next result visible. A changed object reaches Prometheus and Alertmanager after about a minute, so wait before each check. After each step you can run `astrona submit` to see which checks turn green.

## Step 1: Get scout scraped

Read the label the Prometheus resource selects, the labels of the ServiceMonitor and the labels of the Service:

```sh
kubectl -n monitoring get prometheus kps-prometheus -o yaml | grep -A2 serviceMonitorSelector
kubectl -n frontier get servicemonitors.monitoring.coreos.com scout --show-labels
kubectl -n frontier get service scout --show-labels
kubectl -n frontier get servicemonitors.monitoring.coreos.com scout -o jsonpath='{.spec.selector}{"\n"}'
```

```text
  serviceMonitorSelector:
    matchLabels:
      release: kps
NAME    AGE   LABELS
scout   12m   release=prometheus
NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   LABELS
scout   ClusterIP   10.96.150.140   <none>        9898/TCP   12m   app=scout
{"matchLabels":{"app":"frontier-scout"}}
```

Two things are wrong. Prometheus reads only ServiceMonitors with the label `release: kps`, and this one has `release: prometheus`. The selector asks for `app: frontier-scout`, but the Service has `app: scout`. Save this as `servicemonitor-scout.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: scout
  namespace: frontier
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app: scout
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

Apply it:

```sh
kubectl apply -f servicemonitor-scout.yaml
```

After about a minute, Prometheus lists both pods. With a port-forward to Prometheus on `9090` running (`kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090`), check the targets:

```sh
curl -s http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="scout") | "\(.labels.job)\t\(.scrapeUrl)\t\(.health)"'
```

```text
scout	http://10.244.0.10:9898/metrics	up
scout	http://10.244.0.11:9898/metrics	up
```

The check `target-up` passes. The addresses differ in your cluster.

## Step 2: Fix the recording rule and the alert

Print the rules of the PrometheusRule `scout`:

```sh
kubectl -n frontier get prometheusrule scout -o jsonpath='{.spec.groups[0].rules}' | jq .
```

The recording rule filters on `status="5xx"`. The label `status` holds the real code, for example `500`, so no series matches and the division returns nothing. The alert compares the ratio with `5`, which is 500%, and waits `10m`. A ratio is a number between `0` and `1`, so 5% is `0.05`. Save this as `prometheusrule-scout.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout
  namespace: frontier
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
            team: frontier
          annotations:
            summary: "scout in {{ $labels.namespace }} fails more than 5% of requests"
```

Apply it:

```sh
kubectl apply -f prometheusrule-scout.yaml
```

After about a minute, query the recorded series:

```sh
curl -s 'http://127.0.0.1:9090/api/v1/query?query=namespace:http_requests_error_ratio:rate1m' | jq -c '.data.result'
```

```text
[{"metric":{"__name__":"namespace:http_requests_error_ratio:rate1m","namespace":"frontier"},"value":[1793657392.336,"0.14285714285714285"]}]
```

About one request in six fails, so the value is near `0.17`. It moves a little with each query. The alert first shows as `pending`, then as `firing` one minute later. The checks `recorded-ratio` and `alert-firing` pass.

## Step 3: Route the alert to the receiver

The alert fires, but the receiver log is still empty. Print the routing part of the running Alertmanager configuration and the matchers of the AlertmanagerConfig:

```sh
kubectl -n frontier get alertmanagerconfig frontier -o jsonpath='{.spec.route.matchers}{"\n"}'
kubectl -n frontier get alertmanagerconfig frontier -o jsonpath='{.spec.receivers[0].webhookConfigs[0].url}{"\n"}'
```

```text
[{"matchType":"=","name":"severity","value":"critical"}]
http://alert-receiver.monitoring:80/
```

The route matches `severity=critical`, but the alert has `severity: warning`, so Alertmanager sends it to the default receiver. The task asks for the label `team: frontier`. The URL also uses port `80`, but the Service `alert-receiver` listens on `8080`. Do not change the Service or the alert labels. Save this as `alertmanagerconfig-frontier.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: frontier
  namespace: frontier
spec:
  route:
    receiver: frontier-webhook
    matchers:
      - name: team
        value: frontier
        matchType: "="
    groupBy: ["alertname"]
    groupWait: 10s
    groupInterval: 30s
    repeatInterval: 1m
  receivers:
    - name: frontier-webhook
      webhookConfigs:
        - url: http://alert-receiver.monitoring:8080/
          sendResolved: true
```

Apply it:

```sh
kubectl apply -f alertmanagerconfig-frontier.yaml
```

Wait about two minutes, then read the log of the receiver:

```sh
kubectl -n monitoring logs deploy/alert-receiver | tail -3
```

```text
frontier/frontier/frontier-webhook firing ScoutHighErrorRatio namespace=frontier severity=warning startsAt=2026-11-02T22:09:11.785Z
```

The receiver name starts with `frontier/frontier/` because the Prometheus Operator adds the namespace of the AlertmanagerConfig to the name. The check `alert-delivered` passes.

## Step 4: Submit

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

All five checks pass. Some shortcuts fail on purpose. A fixed value such as `vector(0.2)` in the recording rule fails `design-intact`. Changing the port of the Service `alert-receiver` to `80` also fails `design-intact`. Widening the selectors of the Prometheus resource or deleting an object fails it too. Clean up:

```sh
astrona destroy ats-020-capstone-010
```

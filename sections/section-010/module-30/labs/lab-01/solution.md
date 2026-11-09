# Solution: Create And Verify An Alerting Rule

## Inspect the starting state

```sh
kubectl -n starfleet get prometheusrule,alertmanagerconfig
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts | jq .data.alerts
```

## Make the repair

Save this as `prometheusrule-scout-errors.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-errors
  namespace: starfleet
  labels:
    release: kps
spec:
  groups:
  - name: scout-errors
    interval: 15s
    rules:
    - alert: ScoutErrorRate
      expr: sum by (namespace) (rate(http_requests_total{job="scout",namespace="starfleet",status="500"}[1m])) >
        0.1
      for: 1m
      labels:
        team: scout
        severity: warning
```

Apply it:

```sh
kubectl apply -f prometheusrule-scout-errors.yaml
```

## Verify the result

```sh
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/rules | jq '.data.groups[].rules[] | select(.name == "ScoutErrorRate")'
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-010/module-30/labs/lab-01
```

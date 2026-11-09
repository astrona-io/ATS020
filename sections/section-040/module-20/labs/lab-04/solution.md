# Solution: Record Availability And Error Budget

## Inspect the starting state

```sh
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout:9898/metrics | grep http_requests_total
```

## Make the repair

Save this as `scout-sli.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-sli
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
  - name: scout-sli
    rules:
    - record: scout:sli:ratio_rate5m
      expr: sum(rate(http_requests_total{namespace="starfleet",container="scout",status!~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[5m]))
    - record: scout:sli:ratio_rate1h
      expr: sum(rate(http_requests_total{namespace="starfleet",container="scout",status!~"5.."}[1h])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[1h]))
    - record: scout:error_budget_remaining:ratio1h
      expr: 1 - (1 - scout:sli:ratio_rate1h) / (1 - 0.99)
```

Apply it:

```sh
kubectl apply -f scout-sli.yaml
```

## Verify the result

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=scout:error_budget_remaining:ratio1h' | jq .data.result
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-040/module-20/labs/lab-04
```

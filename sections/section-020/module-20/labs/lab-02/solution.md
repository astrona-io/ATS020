# Solution: Scrape Collector Error Metrics

## Inspect the starting state

```sh
kubectl -n monitoring get opentelemetrycollector logs -o yaml
kubectl -n monitoring logs daemonset/logs-collector --tail=30
kubectl -n monitoring get servicemonitor logs-collector -o yaml
```

## Make the repair

Save this as `collector-repair.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: logs-collector
  namespace: monitoring
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: monitoring.logs
      operator.opentelemetry.io/collector-service-type: base
  endpoints:
  - port: prometheus
    interval: 15s
```

Apply it:

```sh
kubectl apply -f collector-repair.yaml
```

## Verify the result

Wait for metadata enrichment, scraping and batching. Query twice, at least 30 seconds apart:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

```sh
curl -sG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=log_error_lines_total{k8s_namespace_name="outpost",k8s_deployment_name="probe"}' | jq .data.result
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-020/module-20/labs/lab-02
```

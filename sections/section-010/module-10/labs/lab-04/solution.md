# Solution: Scrape Pods With A PodMonitor

## Inspect the starting state

```sh
kubectl -n outpost get pods -l app=scout --show-labels
kubectl -n outpost get deployment scout -o yaml
```

## Make the repair

Save this as `podmonitor-scout.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: scout
  namespace: outpost
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app: scout
  podMetricsEndpoints:
  - port: http
    path: /metrics
    interval: 15s
```

Apply it:

```sh
kubectl apply -f podmonitor-scout.yaml
```

## Verify the result

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/targets?state=active' | jq '.data.activeTargets[] | select(.scrapePool == "podMonitor/outpost/scout/0") | {labels, health}'
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-010/module-10/labs/lab-04
```

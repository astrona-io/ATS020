# Solution: Measure Deployment Frequency

## Inspect the starting state

```sh
kubectl -n argocd get application scout -o json | jq .status.history
kubectl -n monitoring get prometheusrule dora-scout -o yaml
```

## Make the repair

Save this as `deployment-frequency.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: dora-scout
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
  - name: dora-scout
    rules:
    - record: dora:deployments:increase6h
      expr: round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))
```

Apply it:

```sh
kubectl apply -f deployment-frequency.yaml
```

## Verify the result

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=dora:deployments:increase6h' | jq .data.result
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-040/module-10/labs/lab-02
```

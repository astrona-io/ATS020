# Solution: Extend Raw Prometheus Pod Discovery

## Inspect the starting state

```sh
kubectl -n monitoring get configmap prometheus-raw -o yaml
kubectl -n starfleet get pods --show-labels
```

## Make the repair

Edit the ConfigMap and change the telemetry keep expression to `primary|reserve`, then load it:

```sh
kubectl -n monitoring edit configmap prometheus-raw
kubectl -n monitoring rollout restart deployment/prometheus-raw
kubectl -n monitoring rollout status deployment/prometheus-raw --timeout=180s
```

## Verify the result

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/targets?state=active' | jq '.data.activeTargets[] | {labels, health, scrapeUrl}'
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-010/module-10/labs/lab-02
```

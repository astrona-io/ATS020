# Solution: Restore The Prometheus Operator

## Inspect the starting state

```sh
kubectl -n monitoring get deployment kps-operator
kubectl -n starfleet get servicemonitor scout
kubectl -n starfleet get prometheusrule scout-alerts
```

## Make the repair

```sh
kubectl -n monitoring scale deployment/kps-operator --replicas=1
kubectl -n monitoring rollout status deployment/kps-operator --timeout=180s
```

## Verify the result

Wait for reconciliation and scraping, then inspect the target and rule:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=up%7Bjob%3D%22scout%22%7D' | jq .data.result
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/rules | jq '.data.groups[].rules[] | select(.name == "ScoutDown")'
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-050/module-20/labs/lab-03
```

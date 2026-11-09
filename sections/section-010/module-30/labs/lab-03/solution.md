# Solution: Silence A Maintenance Alert

## Inspect the starting state

```sh
kubectl -n starfleet get prometheusrule,alertmanagerconfig
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts | jq .data.alerts
```

## Make the repair

```sh
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- \
  amtool silence add alertname=ProbeMaintenance namespace=starfleet \
  --duration=30m --author=platform --comment='probe maintenance window' \
  --alertmanager.url=http://localhost:9093
```

## Verify the result

```sh
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts | jq '.[] | {labels, status}'
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts | jq .data.alerts
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-010/module-30/labs/lab-03
```

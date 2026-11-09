# Solution: Route An Alert To Its Receiver

## Inspect the starting state

```sh
kubectl -n starfleet get prometheusrule,alertmanagerconfig
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts | jq .data.alerts
```

## Make the repair

Save this as `alertmanagerconfig-scout-routing.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: scout-routing
  namespace: starfleet
spec:
  route:
    receiver: scout-webhook
    matchers:
    - name: team
      value: scout
      matchType: '='
    groupBy:
    - namespace
    - alertname
    groupWait: 5s
    groupInterval: 15s
    repeatInterval: 5m
  receivers:
  - name: scout-webhook
    webhookConfigs:
    - url: http://alert-receiver.monitoring:8080/
      sendResolved: true
```

Apply it:

```sh
kubectl apply -f alertmanagerconfig-scout-routing.yaml
```

## Verify the result

```sh
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts | jq '.[] | select(.labels.alertname == "ScoutErrorRate") | {status, receivers}'
kubectl -n monitoring logs deploy/alert-receiver --tail=20
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-010/module-30/labs/lab-02
```

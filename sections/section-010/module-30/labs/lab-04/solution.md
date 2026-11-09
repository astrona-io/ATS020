# Solution: Inhibit A Related Warning Alert

## Inspect the starting state

```sh
kubectl -n starfleet get prometheusrule,alertmanagerconfig
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts | jq '.[] | {labels, status, receivers}'
```

## Make the repair

Save this as `alertmanagerconfig-repair.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: scout-inhibition
  namespace: starfleet
spec:
  route:
    receiver: scout-webhook
    matchers:
    - name: team
      value: scout-inhibit
      matchType: '='
    groupBy:
    - namespace
    - alertname
    groupWait: 10s
    groupInterval: 1m
    repeatInterval: 5m
  receivers:
  - name: scout-webhook
    webhookConfigs:
    - url: http://alert-receiver.monitoring:8080/
  inhibitRules:
  - sourceMatch:
    - name: team
      value: scout-inhibit
      matchType: '='
    - name: severity
      value: critical
      matchType: '='
    - name: alertname
      value: ScoutUnavailable
      matchType: '='
    targetMatch:
    - name: team
      value: scout-inhibit
      matchType: '='
    - name: severity
      value: warning
      matchType: '='
    - name: alertname
      value: ScoutLatency
      matchType: '='
    equal:
    - namespace
    - team
```

Apply it:

```sh
kubectl apply -f alertmanagerconfig-repair.yaml
```

## Verify the result

Allow the Operator to merge the configuration, then inspect the live state:

```sh
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts | jq '.[] | {labels, fingerprint, status, receivers}'
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts/groups | jq .
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-010/module-30/labs/lab-04
```

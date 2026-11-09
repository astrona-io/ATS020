# Solution: Repair Route Precedence And Grouping

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
  name: scout-decisions
  namespace: starfleet
spec:
  route:
    receiver: scout-default
    matchers:
    - name: team
      value: scout
      matchType: '='
    groupBy:
    - namespace
    - alertname
    groupWait: 10s
    groupInterval: 1m
    repeatInterval: 5m
    routes:
    - receiver: scout-warning
      matchers:
      - name: severity
        value: warning
        matchType: '='
      continue: true
    - receiver: scout-archive
      matchers:
      - name: alertname
        value: Scout.*
        matchType: =~
  receivers:
  - name: scout-default
    webhookConfigs:
    - url: http://alert-receiver.monitoring:8080/
  - name: scout-warning
    webhookConfigs:
    - url: http://alert-receiver.monitoring:8080/
  - name: scout-archive
    webhookConfigs:
    - url: http://alert-receiver.monitoring:8080/
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
astrona submit -c sections/section-010/module-30/labs/lab-05
```

# Solution: Provision The Prometheus Data Source

## Inspect the starting state

```sh
kubectl -n monitoring get configmap datasource-prometheus -o yaml
kubectl -n monitoring get deployment kps-grafana -o yaml
```

## Make the repair

Save this as `configmap-datasource-prometheus.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: datasource-prometheus
  namespace: monitoring
  labels:
    grafana_datasource: '1'
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        uid: prometheus
        access: proxy
        url: http://kps-prometheus.monitoring:9090
        isDefault: true
        jsonData:
          timeInterval: 15s
```

Apply it:

```sh
kubectl apply -f configmap-datasource-prometheus.yaml
```

## Verify the result

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

In another terminal:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3000/api/datasources/uid/prometheus | jq '{uid, url, readOnly}'
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-020/module-10/labs/lab-06
```

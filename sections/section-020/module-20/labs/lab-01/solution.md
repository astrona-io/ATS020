# Solution: Restore Collector Kubernetes Metadata

## Inspect the starting state

```sh
kubectl -n monitoring get opentelemetrycollector logs -o yaml
kubectl -n monitoring logs daemonset/logs-collector --tail=30
kubectl -n monitoring get servicemonitor logs-collector -o yaml
```

## Make the repair

Save this as `collector-repair.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: logs-collector
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: logs-collector
subjects:
- kind: ServiceAccount
  name: logs-collector
  namespace: monitoring
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
astrona submit -c sections/section-020/module-20/labs/lab-01
```

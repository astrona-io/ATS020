# Solution

Solve this lab on `terminal`. Every value below is calculated by Prometheus from the data of the lab, so read your own results and compare them with the ranges in the task.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-040/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Save the rules

Save this as `platform-efficiency.yaml`. The full file is in `solution/solution.yaml`.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: platform-efficiency
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: platform-efficiency
      rules:
        - record: dora:deployments:increase6h
          expr: round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))
        - record: dora:failed_deployments:count6h
          expr: sum(changes((max by (name) (argocd_app_info{name="scout",health_status="Degraded"}) or max by (name) (argocd_app_info{name="scout"}) * 0)[6h:15s])) / 2
        - record: dora:change_failure_rate:ratio6h
          expr: dora:failed_deployments:count6h / dora:deployments:increase6h
        - record: scout:error_ratio:rate5m
          expr: sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[5m]))
        - record: scout:error_ratio:rate1h
          expr: sum(rate(http_requests_total{namespace="starfleet",container="scout",status=~"5.."}[1h])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[1h]))
        - record: scout:error_budget_remaining:ratio1h
          expr: 1 - scout:error_ratio:rate1h / (1 - 0.99)
        - alert: ScoutErrorBudgetBurn
          expr: scout:error_ratio:rate5m / (1 - 0.99) > 2 and scout:error_ratio:rate1h / (1 - 0.99) > 2
          for: 2m
          labels:
            severity: ticket
            service: scout
```

Apply it:

```sh
kubectl apply -f platform-efficiency.yaml
```

Then check that Prometheus loaded the group, after about a minute:

```sh
kubectl get --raw /api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/rules | jq -r '.data.groups[].name' | grep platform-efficiency
```

The command prints `platform-efficiency`.

## Step 2: Read the recorded values

```sh
for q in dora:deployments:increase6h dora:change_failure_rate:ratio6h scout:error_budget_remaining:ratio1h; do
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$q" | jq -r '.data.result[0].value[1]'
done
```

The deployments are between 8 and 11, the change failure rate is between 0.15 and 0.30, and the remaining budget is between -6 and -2.5. The error ratio is about 5%, so the budget of 1% is spent several times over in the 1 hour window.

## Step 3: Right-size beacon

Read the usage and the requests first:

```sh
kubectl -n starfleet top pods --containers
kubectl -n starfleet get deployment beacon -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

Set requests a little above the usage and a memory limit above the request:

```sh
kubectl -n starfleet set resources deployment/beacon --requests=cpu=10m,memory=64Mi --limits=memory=128Mi
kubectl -n starfleet rollout status deployment/beacon
```

Then press Ctrl-C to stop the watch and submit once:

```sh
astrona submit
```

The watch terminal shows all six checks passing after the alert has been firing for two minutes.

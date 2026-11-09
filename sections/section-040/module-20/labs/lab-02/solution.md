# Solution: Reduce Excess Resource Requests

## Inspect the starting state

```sh
kubectl -n starfleet top pods
kubectl -n starfleet get deployment scout -o yaml
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Query `max(max_over_time(container_memory_working_set_bytes{namespace="starfleet",container="scout"}[1h]))` for peak memory. For CPU, use `max(max_over_time(rate(container_cpu_usage_seconds_total{namespace="starfleet",container="scout"}[2m])[1h:30s]))`.

## Make the repair

These values fit the seeded workload; compare them with the measured peaks before applying:

```sh
kubectl -n starfleet set resources deployment/scout --requests=cpu=10m,memory=64Mi --limits=memory=128Mi
```

## Verify the result

```sh
kubectl -n starfleet rollout status deployment/scout --timeout=180s
kubectl -n starfleet get pods
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://scout:9898/
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-040/module-20/labs/lab-02
```

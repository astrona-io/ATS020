# Solution: Raise An Undersized Memory Request

## Inspect the starting state

```sh
kubectl -n starfleet top pods
kubectl -n starfleet get deployment probe -o yaml
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Query `max(max_over_time(container_memory_working_set_bytes{namespace="starfleet",container="probe"}[1h]))` for peak memory. For CPU, use `max(max_over_time(rate(container_cpu_usage_seconds_total{namespace="starfleet",container="probe"}[2m])[1h:30s]))`.

## Make the repair

These values fit the seeded workload; compare them with the measured peaks before applying:

```sh
kubectl -n starfleet set resources deployment/probe --requests=cpu=5m,memory=24Mi
```

## Verify the result

```sh
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet get pods
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://scout:9898/
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-040/module-20/labs/lab-03
```

# Solution: Scale From A Queue Metric

## Inspect the starting state

```sh
kubectl -n monitoring get configmap prometheus-raw -o yaml
kubectl -n starfleet get pods --show-labels
```

## Make the repair

Read the totals before scaling. A gauge reports a current value; use the sum without `rate()`.

```sh
kubectl -n monitoring port-forward svc/prometheus-raw 9090:9090
```

In another terminal:

```sh
curl -sG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=sum by (deployment) (starfleet_queue_items{job="starfleet-pods",namespace="starfleet"})' | jq .data.result
kubectl -n starfleet scale deployment/probe --replicas=3
```

The seeded queue total is highest for `probe`. Base the decision on the query result.

## Verify the result

```sh
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet get deployments
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-010/module-10/labs/lab-03
```

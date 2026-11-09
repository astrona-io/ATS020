# Solution: Repair An Error Ratio Recording Rule

## Inspect the starting state

```sh
kubectl -n monitoring get prometheusrule scout-queries -o yaml
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

## Make the repair

Use matching rates in a ratio; aggregate histogram buckets by `le` before computing a percentile. Update the assigned rule:

```sh
kubectl -n monitoring patch prometheusrule scout-queries --type=json -p '[{"op": "replace", "path": "/spec/groups/0/rules/0/expr", "value": "sum(rate(http_requests_total{namespace=\"starfleet\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{namespace=\"starfleet\"}[5m]))"}]'
```

## Verify the result

Allow the Operator to load the change and Prometheus to evaluate it. Query the recorded value and the source expression:

```sh
curl -sG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=scout:error_ratio:rate5m' | jq .data.result
curl -sG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=sum(rate(http_requests_total{namespace="starfleet",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet"}[5m]))' | jq .data.result
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-010/module-20/labs/lab-02
```

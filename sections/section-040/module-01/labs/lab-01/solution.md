# Solution

The change failure rate is `0` because the rule for the failed deployments counts the wrong signal. It counts sync operations that ended in the phase `Failed` or `Error`. Argo CD never records one for a bad image tag, because it applied the manifest successfully. The failure shows in the health status of the Application instead.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-040/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Find the fault

Open another terminal and leave a port-forward to Prometheus running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Define a helper that sends one PromQL query and prints one line for each result series:

```sh
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.container, .endpoint, .instance, .job, .pod, .service, .exported_namespace, .namespace, .dest_server, .dry_run, .project)), value: .value[1]}'
}
```

Read the ratio and the expression of the failed deployment count:

```sh
promql 'dora:change_failure_rate:ratio6h'
kubectl -n monitoring get prometheusrule dora-scout -o jsonpath='{.spec.groups[0].rules[1].expr}{"\n"}'
```

```text
{"metric":{"__name__":"dora:change_failure_rate:ratio6h"},"value":"0"}
sum(increase(argocd_app_sync_total{name="scout",phase=~"Failed|Error"}[6h])) or vector(0)
```

The rule counts the phases `Failed` and `Error`, and `or vector(0)` returns `0` when there is no such series. Check that no such series exists:

```sh
promql 'argocd_app_sync_total{name="scout",phase=~"Failed|Error"}'
```

The query prints nothing. Every sync ended in `Succeeded`. Now look at the health status:

```sh
promql 'sum by (health_status) (count_over_time(argocd_app_info{name="scout"}[6h]))'
```

```text
{"metric":{"health_status":"Unknown"},"value":"3"}
{"metric":{"health_status":"Healthy"},"value":"55"}
{"metric":{"health_status":"Progressing"},"value":"6"}
{"metric":{"health_status":"Degraded"},"value":"3"}
```

The Application was `Degraded` for a short time. That is the signal for the two failed deployments. The numbers in your output differ, because the `Healthy` count grows with time.

## Fix the rule

The series for `health_status="Degraded"` exists only while the Application is degraded. The expression needs a flag that is always present: `1` while degraded and `0` otherwise. Each failure flips the flag twice, so `changes()` over a subquery, divided by two, counts the failures.

Save this as `prometheusrule-dora-scout.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: dora-scout
  namespace: monitoring
  labels:
    release: kps
spec:
  groups:
    - name: dora-scout
      rules:
        - record: dora:deployments:increase6h
          expr: round(sum(increase(argocd_app_sync_total{name="scout",phase="Succeeded"}[6h])))
        - record: dora:failed_deployments:count6h
          expr: sum(changes((max by (name) (argocd_app_info{name="scout",health_status="Degraded"}) or max by (name) (argocd_app_info{name="scout"}) * 0)[6h:15s])) / 2
        - record: dora:change_failure_rate:ratio6h
          expr: dora:failed_deployments:count6h / dora:deployments:increase6h
```

Apply it:

```sh
kubectl apply -f prometheusrule-dora-scout.yaml
```

Then check the result. A changed rule reaches Prometheus after about a minute, so run the query again if it still prints `0`:

```sh
promql 'dora:failed_deployments:count6h'
promql 'dora:change_failure_rate:ratio6h'
```

```text
{"metric":{"__name__":"dora:failed_deployments:count6h"},"value":"2"}
{"metric":{"__name__":"dora:change_failure_rate:ratio6h"},"value":"0.2222222222222222"}
```

Two failed deployments out of nine counted deployments give `0.22`. If `increase()` counts eight deployments, the rate is `0.25`; both are accepted.

Press Ctrl-C to stop the watch, then grade your work once:

```sh
astrona submit -c sections/section-040/module-01/labs/lab-01
```

## What the grader rejects

- Deleting the rule or the PrometheusRule: the first check needs all three rules.
- Typing the number, for example `vector(2)`: the second check rejects `vector(`.
- Counting `phase=~"Failed|Error"` again, with another way to hide the zero: the second check rejects the sync phases.
- Changing the deployments rule so that the ratio fits: the first check needs the original expression.

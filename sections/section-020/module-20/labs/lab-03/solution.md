# Solution: Repair Container Log File Collection

## Inspect the starting state

```sh
kubectl -n monitoring get opentelemetrycollector logs -o yaml
kubectl -n monitoring logs daemonset/logs-collector --tail=30
```

## Make the repair

Edit `spec.config.receivers.file_log.include` to use `/var/log/pods/*/*/*.log`. Keep the existing exclusion and `type: container` parser.

```sh
kubectl -n monitoring edit opentelemetrycollector logs
```

## Verify the result

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Query `log_error_lines_total{k8s_namespace_name="outpost",k8s_deployment_name="probe"}` twice, at least 30 seconds apart. The counter must rise.

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-020/module-20/labs/lab-03
```

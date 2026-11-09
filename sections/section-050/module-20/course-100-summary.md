# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Repair A Webhook Service Port | A Deployment can be created in starfleet, and the starfleet-policy webhook answered the request; Both webhook configurations keep failurePolicy Fail, and the workloads, ServiceMonitor and PrometheusRule are still in place |
| Renew An Expired Webhook Certificate | A Deployment can be created in outpost, and the outpost-policy webhook answered the request; Both webhook configurations keep failurePolicy Fail, and the workloads, ServiceMonitor and PrometheusRule are still in place |
| Restore The Prometheus Operator | The Prometheus Operator runs, up{job="scout"} is 1 and the ScoutDown rule is loaded in Prometheus; Both webhook configurations keep failurePolicy Fail, and the workloads, ServiceMonitor and PrometheusRule are still in place |
| Recover A GitOps Source Path | The original Application syncs its Git revision and keeps scout healthy |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

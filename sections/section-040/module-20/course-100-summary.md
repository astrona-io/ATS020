# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Record Availability And Error Budget | Live recording rules report the request SLI and remaining budget for a 99 percent objective |
| Repair A Multi-Window Burn-Rate Alert | The PrometheusRule scout-slo keeps its two recording rules and its multi-window alert with a real threshold and a short for; Both recording rules return the real error ratio of scout, from the request counter; Prometheus reports the alert ScoutErrorBudgetBurn in the state firing |
| Reduce Excess Resource Requests | The running scout pods request memory and CPU close to measured peak usage and keep a memory limit; Replicas, readiness and restarts are unchanged and scout still answers 200 to shuttle |
| Raise An Undersized Memory Request | The running probe pod requests at least its measured peak memory, with a bounded request and a memory limit; Replicas, readiness and restarts are unchanged and scout still answers 200 to shuttle |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

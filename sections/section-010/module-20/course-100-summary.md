# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Repair An Error Ratio Recording Rule | The PrometheusRule scout-queries keeps both recording rules, and they read the real metrics; scout:error_ratio:rate5m returns one series that matches the real error ratio |
| Repair A Latency Percentile Recording Rule | The PrometheusRule scout-queries keeps both recording rules, and they read the real metrics; scout:request_duration_seconds:p95_5m returns one series that matches the real p95 latency |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

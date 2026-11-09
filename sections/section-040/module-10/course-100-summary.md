# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Measure Deployment Frequency | The recorded count matches successful syncs in live Prometheus data |
| Repair The Change Failure Rate Rule | The PrometheusRule dora-scout still has its three recording rules and the deployments rule is unchanged; The failed deployment count reads the Degraded health of the Application, with no typed-in number; Prometheus returns a change failure rate between 0.15 and 0.30 |
| Calculate Lead Time From Git Revisions | Submitted durations match the live deployment history and Git commits |
| Measure Time To Restore Service | Submitted durations match the live deployment history and Git commits |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

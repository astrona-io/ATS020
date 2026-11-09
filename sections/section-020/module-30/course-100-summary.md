# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Repair A Loki Error Dashboard | The Loki data source is editable, healthy and has Maximum lines set to 250; The two saved panels query the outpost error lines and count their streams |
| Find And Stop Error-Logging Workloads | Every controller in outpost that wrote ERROR lines runs no Pods and the others still run |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Create And Verify An Alerting Rule | The selected rule uses the requested metric, threshold, duration and labels; ScoutErrorRate fires for starfleet |
| Route An Alert To Its Receiver | The selected rule uses the requested metric, threshold, duration and labels; ScoutErrorRate fires for starfleet; Alertmanager assigns the alert to the webhook and the receiver logs it |
| Silence A Maintenance Alert | An active scoped 30-minute silence suppresses the maintenance alert |
| Inhibit A Related Warning Alert | The live alert state and grouping match the task |
| Repair Route Precedence And Grouping | The live alert state and grouping match the task |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

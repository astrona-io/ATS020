# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Repair Container Log File Collection | Prometheus scrapes the Collector's metric endpoint and the target is up; log_error_lines_total carries the probe deployment and outpost namespace labels and keeps rising; The Collector keeps its pipeline and gets only read access to pods |
| Restore Collector Kubernetes Metadata | Prometheus scrapes the Collector's metric endpoint and the target is up; log_error_lines_total carries the probe deployment and outpost namespace labels and keeps rising; The Collector keeps its pipeline and gets only read access to pods |
| Scrape Collector Error Metrics | Prometheus scrapes the Collector's metric endpoint and the target is up; log_error_lines_total carries the probe deployment and outpost namespace labels and keeps rising; The Collector keeps its pipeline and gets only read access to pods |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

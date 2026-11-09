# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Scrape Pods With A PodMonitor | Every ready scout Pod is scraped through its PodMonitor |
| Repair ServiceMonitor Discovery | The Prometheus resource, the Service scout and the label release kps are unchanged; Every ready scout endpoint is a healthy Prometheus target with up equal to 1 |
| Extend Raw Prometheus Pod Discovery | The raw job scrapes all primary and reserve Pods and excludes disabled Pods |
| Scale From A Queue Metric | The raw job scrapes all primary and reserve Pods and excludes disabled Pods; The Deployment with the highest live queue total has three ready replicas; the others have one |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

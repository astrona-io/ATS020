# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Schedule A Pending Workload | scout has a Running pod from the original image and answers 200 to shuttle; The assigned workload keeps one replica and its Service; shuttle keeps its image |
| Repair A Crashing Process | beacon runs podinfo 6.17.0 and answers 200; The assigned workload keeps one replica and its Service; shuttle keeps its image |
| Repair A Failing Liveness Probe | probe keeps its liveness probe, stays Ready without new restarts and answers 200; The assigned workload keeps one replica and its Service; shuttle keeps its image |
| Repair An OOMKilled Workload | cargo keeps a memory limit that fits its use (256Mi to 1Gi), has no OOMKilled restart and answers 200; The assigned workload keeps one replica and its Service; shuttle keeps its image |
| Repair An Image Reference | beacon runs podinfo 6.17.0 and answers 200; The assigned workload keeps one replica and its Service; shuttle keeps its image |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

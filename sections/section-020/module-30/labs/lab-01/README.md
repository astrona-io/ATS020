---
estimated_duration: 25m
---
# Query Loki And Stop The Failing Workloads Lab

- **Slug:** ats-020-lab-020-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

Grafana 13.2.3 has an editable Loki data source and a saved dashboard whose two
panels query the wrong namespace. Loki 3.7.9 receives the logs of `outpost` and
`starfleet` from a Collector DaemonSet, which is plumbing. The learner changes
Maximum lines, corrects both panels and uses a query result to scale the
controllers of the Pods that write errors to 0. The grader runs the saved panel
queries against Loki and works out the expected controllers from Loki.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-30/labs/lab-01
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-30/labs/lab-01
astrona destroy ats-020-lab-020-03
```

Bootstrap installs Helm 4.3.1 only if Helm is missing. The terminal needs
kubectl, curl and jq.

Author status: built without booting on 2026-11-04. Runtime behaviour remains untested.

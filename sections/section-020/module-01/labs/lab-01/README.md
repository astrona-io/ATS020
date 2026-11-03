---
estimated_duration: 25m
---

# Fix A Grafana Dashboard That Is Provisioned From A ConfigMap

Graded lab for the dashboards module. The dashboard `scout-overview` is stored in a ConfigMap, but it never appears in Grafana. The learner finds two faults: the ConfigMap lacks the label the Grafana dashboard sidecar watches, and every panel names a data source UID that does not exist. The grader checks that Grafana reports the dashboard as provisioned, that all three panels still exist and return data, and that the fix did not replace the provisioned data source with one made by hand.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-01/labs/lab-01
astrona submit -c sections/section-020/module-01/labs/lab-01
astrona destroy ats-020-lab-020-01
```

Authors can run the reference solution with `astrona test -c sections/section-020/module-01/labs/lab-01`.

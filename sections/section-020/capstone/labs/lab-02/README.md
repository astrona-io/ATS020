---
estimated_duration: 35m
---
# Trace One Incident Through Grafana, Prometheus And Loki

- **Slug:** ats-020-capstone-020-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

One service in `outpost` fails because of a wrong environment value. Prometheus
shows which service fails, Loki shows why, and a Grafana dashboard should show
both. The learner adds the Loki data source, corrects both panels, saves the two
findings to files and fixes the Deployment. The grader compares the files with
Prometheus and Loki and proves recovery from live data.

The stack is a trimmed kube-prometheus-stack 92.3.0 (the Prometheus Operator, one
Prometheus and Grafana 13.2.3), Loki 3.7.9 in single-binary mode and a Collector
DaemonSet as plumbing. The services are a small Python application.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/capstone/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/capstone/labs/lab-02
astrona destroy ats-020-capstone-020-02
```

Bootstrap installs Helm 4.3.0 only if Helm is missing. The terminal needs
kubectl, curl and jq.

Author status: built without booting on 2026-11-04. Runtime behaviour remains untested.

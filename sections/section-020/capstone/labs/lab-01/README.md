---
estimated_duration: 60m
---

# Dashboards And Logs Capstone

- **Slug:** ats-020-capstone-020
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8 with cert-manager 1.21.3,
the OpenTelemetry Operator 0.162.0 and a trimmed kube-prometheus-stack 92.3.0
(the Prometheus Operator, one Prometheus and Grafana 13.2.3). The namespace
`outpost` runs `scout` (with metrics) and `probe` (logs only), and a `shuttle`
pod sends traffic with errors to both. The Grafana data source is provisioned
correctly. A dashboard ConfigMap exists with two faults. The learner builds the
log pipeline (Collector, permission, ServiceMonitor) and fixes the dashboard,
and proves it with a rising metric and three panels that show data.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/capstone/labs/lab-01
astrona submit -c sections/section-020/capstone/labs/lab-01
astrona destroy ats-020-capstone-020
```

Authors run a local copy with `astrona run -c .` and prove the reference
solution with `astrona test -c .`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition |
| `prerequisites.md` | What the learner needs first |
| `question.md` | The task |
| `solution.md` | The walkthrough with real output |
| `bootstrap/01-prepare.sh` | Installs cert-manager, the Operator and the trimmed stack |
| `bootstrap/kps-values.yaml` | Helm values for the stack |
| `manifests/lab-start.yaml` | `scout`, `probe`, the ServiceMonitor, `shuttle` and the data source |
| `manifests/dashboard-start.yaml` | The faulty dashboard ConfigMap (the faults are the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-prometheus.sh` | Waits for the scout metrics and the log metric |
| `validation/` | One script per check |

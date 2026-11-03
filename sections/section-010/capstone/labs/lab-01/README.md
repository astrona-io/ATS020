---
estimated_duration: 45m
---

# Metrics And Alerting Capstone

- **Slug:** ats-020-capstone-010
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8 with a trimmed
kube-prometheus-stack 92.3.0 (the Prometheus Operator, one Prometheus and one
Alertmanager). The namespace `frontier` runs `scout` with two pods, and a
`shuttle` pod makes about one request in six fail. A small `alert-receiver`
webhook in `monitoring` prints every notification it gets. The bootstrap then
applies a ServiceMonitor, a PrometheusRule and an AlertmanagerConfig that are
wrong in three independent ways: no target, a recording rule and an alert that
never produce a result, and a route that never reaches the receiver. The
learner fixes all three and proves each fix with a query or a notification.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/capstone/labs/lab-01
astrona submit -c sections/section-010/capstone/labs/lab-01
astrona destroy ats-020-capstone-010
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
| `bootstrap/01-prepare.sh` | Installs the trimmed Prometheus stack |
| `bootstrap/kps-values.yaml` | Helm values for the stack |
| `manifests/lab-start.yaml` | `scout`, `shuttle` and `alert-receiver` |
| `manifests/monitoring-start.yaml` | The faulty ServiceMonitor, PrometheusRule and AlertmanagerConfig (the faults are the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-delivery.sh` | Waits for two healthy targets and a delivered alert |
| `validation/` | One script per check |

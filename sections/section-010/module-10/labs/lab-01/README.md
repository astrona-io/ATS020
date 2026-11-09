---
estimated_duration: 20m
---

# Get A Workload Scraped With A ServiceMonitor Lab

- **Slug:** ats-020-lab-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs a
trimmed kube-prometheus-stack 92.22.0 (the Prometheus Operator and one
Prometheus, no Alertmanager, no Grafana) and the workload `scout` in
`starfleet`, with two pods behind a Service. Then it applies a ServiceMonitor
`scout` with three mistakes: the wrong `release` label, a port name the
Service does not have, and a wrong path. The learner finds each mistake, fixes
the ServiceMonitor and proves it with `up == 1` for every `scout` endpoint.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-10/labs/lab-01
astrona submit -c sections/section-010/module-10/labs/lab-01
astrona destroy ats-020-lab-010-01
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
| `manifests/lab-start.yaml` | The `scout` Deployment and Service |
| `manifests/servicemonitor-start.yaml` | The faulty ServiceMonitor (the fault is the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-targets.sh` | Waits for two healthy `scout` targets |
| `validation/` | One script per check |

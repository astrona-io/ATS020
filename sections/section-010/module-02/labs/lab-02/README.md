---
estimated_duration: 25m
---

# Record The Error Ratio And p95 Latency Lab

- **Slug:** ats-020-lab-010-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs a
trimmed kube-prometheus-stack 92.3.0 (the Prometheus Operator and one
Prometheus, no Alertmanager, no Grafana), the `scout` workloads in `starfleet`
and `outpost` with their ServiceMonitors, and a `shuttle` pod that sends steady
traffic, including failing and slow requests. Then it applies a PrometheusRule
`scout-queries` with two faulty recording rules. The error ratio divides a rate
by a raw counter. The p95 latency has no `sum by (le)`. The learner fixes both
expressions and proves it by querying the recorded series.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-02/labs/lab-02
astrona submit -c sections/section-010/module-02/labs/lab-02
astrona destroy ats-020-lab-010-02
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
| `manifests/lab-start.yaml` | The workloads, their ServiceMonitors and the traffic loop |
| `manifests/rules-start.yaml` | The faulty PrometheusRule (the fault is the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-rules.sh` | Waits until both rules return one series |
| `validation/` | One script per check |

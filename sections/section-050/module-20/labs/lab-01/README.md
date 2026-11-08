---
estimated_duration: 40m
---

# Restore A Platform After Three Failures Lab

- **Slug:** ats-020-lab-050-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8 with a trimmed
kube-prometheus-stack 92.3.0 (Prometheus Operator and one Prometheus). The
platform starts broken in three independent ways. The Service of the
`starfleet-policy` webhook sends traffic to a port the server does not open, so
every create of a Deployment in `starfleet` fails. The serving certificate of the
`outpost-policy` webhook expired, so every create in `outpost` fails. The
Prometheus Operator is scaled to zero, so `scout` is not scraped and its alert
rule is not loaded. The learner fixes all three and proves each fix.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-20/labs/lab-01
astrona submit -c sections/section-050/module-20/labs/lab-01
astrona destroy ats-020-lab-050-02
```

Authors run a local copy with `astrona run -c .` and prove the reference
solution with `astrona test -c .`. The reference solution needs `openssl`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition |
| `prerequisites.md` | What the learner needs first |
| `question.md` | The task |
| `solution.md` | The walkthrough with real output |
| `bootstrap/01-prepare.sh` | Installs the trimmed Prometheus stack, then scales the operator to zero |
| `bootstrap/kps-values.yaml` | Helm values for kube-prometheus-stack |
| `manifests/lab-start.yaml` | The workloads, the two webhooks with their CA and certificates, the ServiceMonitor and the PrometheusRule (the faults are the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-platform.sh` | Waits for the webhook servers and the operator before grading in tests |
| `validation/` | One script per check |

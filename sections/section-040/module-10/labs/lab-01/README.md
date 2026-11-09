---
estimated_duration: 25m
---

# Fix The Change Failure Rate Rule Lab

- **Slug:** ats-020-lab-040-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs a
trimmed kube-prometheus-stack 92.3.0, Gitea 28.1.0 (plumbing) and Argo CD
3.6.1, then makes ten real deployments of `scout`, two of them bad on purpose.
Then it applies a PrometheusRule `dora-scout` whose failed deployment count
reads the sync phases `Failed` and `Error` and therefore returns `0`. The
learner finds the fault, changes the rule to read the `Degraded` health from
`argocd_app_info`, and proves it with the change failure rate in Prometheus.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-10/labs/lab-01
astrona submit -c sections/section-040/module-10/labs/lab-01
astrona destroy ats-020-lab-040-01
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
| `bootstrap/01-prepare.sh` | Installs Prometheus, Gitea and Argo CD, then runs the seed |
| `bootstrap/seed-history.sh` | Makes ten backdated commits and waits for Argo CD to sync each one |
| `bootstrap/*.yaml` | Gitea, the trimmed Prometheus stack, the Argo CD project, Application and ServiceMonitor |
| `manifests/lab-start.yaml` | The `shuttle` client |
| `manifests/dora-rules-start.yaml` | The faulty PrometheusRule (the fault is the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-rule.sh` | Waits for Prometheus to return the fixed rate |
| `validation/` | One script per check |

---
estimated_duration: 20m
---

# Fix The Burn-Rate Alert Lab

- **Slug:** ats-020-lab-040-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs a
trimmed kube-prometheus-stack 92.3.0 with kube-state-metrics and starts the
Starfleet workloads. A traffic loop makes 1 of every 20 requests to `scout`
fail. Then it applies a PrometheusRule `scout-slo` whose recording rules use the
status selector `5xx`, which matches no status. Both recording rules return no
data and the burn-rate alert never fires. The learner finds the fault, fixes the
selector and proves it with the error ratio and the firing alert in Prometheus.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-02/labs/lab-01
astrona submit -c sections/section-040/module-02/labs/lab-01
astrona destroy ats-020-lab-040-02
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
| `bootstrap/kps-values.yaml` | Chart values: kube-state-metrics and kubelet scraping on, the rest off |
| `manifests/lab-start.yaml` | `scout`, `probe`, `shuttle`, the traffic loop and the ServiceMonitor |
| `manifests/slo-rules-start.yaml` | The faulty PrometheusRule (the fault is the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-ratio.sh` | Waits for Prometheus to return the fixed error ratio |
| `validation/` | One script per check |

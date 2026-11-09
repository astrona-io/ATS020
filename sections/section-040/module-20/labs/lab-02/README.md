---
estimated_duration: 20m
---

# Right-Size Two Deployments Lab

- **Slug:** ats-020-lab-040-02-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs a
trimmed kube-prometheus-stack 92.22.0 with kube-state-metrics and metrics-server
(from the kind addon) and starts the Starfleet workloads. `scout` has 2
replicas and requests 250m CPU and 256Mi memory, but uses about 3m CPU and 35Mi
memory. `probe` requests 2Mi memory, but uses more. A traffic loop keeps both
busy. The learner compares requests with measured usage and changes both
Deployments so each request is close to the measured peak, with a memory limit
kept and the service still running.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-20/labs/lab-02
astrona submit -c sections/section-040/module-20/labs/lab-02
astrona destroy ats-020-lab-040-02-02
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
| `manifests/lab-start.yaml` | `scout`, `probe`, `shuttle`, the traffic loop and the ServiceMonitor (the wrong requests are the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-usage.sh` | Waits until Prometheus holds usage data |
| `validation/` | One script per check |

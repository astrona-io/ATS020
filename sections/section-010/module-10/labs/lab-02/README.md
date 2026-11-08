---
estimated_duration: 20m
---

# Extend Raw Prometheus Discovery And Scale A Workload Lab

- **Slug:** ats-020-lab-010-01-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node Kubernetes 1.35.8 environment runs Prometheus 3.15.0 directly
from a ConfigMap, without an Operator. Three small Python metric servers
expose a synthetic queue gauge. Pod discovery initially includes only the
primary label value. The learner adds the reserve value, loads the change,
queries totals by Deployment and scales the busiest selected workload.
The disabled workload tests that discovery remains selective.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-10/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-10/labs/lab-02
astrona destroy ats-020-lab-010-01-02
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment, preloaded images and grading |
| `prerequisites.md` | Terminal tools and starting state |
| `question.md` | Task |
| `solution.md` | Walkthrough and expected observations |
| `bootstrap/01-prepare.sh` | Check terminal tools |
| `manifests/lab-start.yaml` | Discovery permissions, plain Prometheus and metric servers |
| `solution/` | Correct ConfigMap and reference apply script |
| `testing/wait-for-targets.sh` | Wait for target convergence |
| `validation/` | Compare live targets and replica counts with live metric data |

Authored for Astrona CLI v0.4.14. Built without booting on 2026-11-04;
no runtime result is claimed.

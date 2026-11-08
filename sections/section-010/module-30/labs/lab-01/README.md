---
estimated_duration: 25m
---

# Route A Team Alert And Silence Maintenance Lab

- **Slug:** ats-020-lab-010-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

The learner writes one PrometheusRule, fixes a team matcher and creates a
scoped maintenance silence. Bootstrap uses kube-prometheus-stack 92.3.0,
Kubernetes 1.35.8, the section's `scout` and `shuttle` workloads and the
small Python webhook receiver. Grafana, default rules, node-exporter and
kube-state-metrics are disabled. `ProbeMaintenance` is a constant diagnostic
fixture; `ScoutErrorRate` must read live request data.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-30/labs/lab-01
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-30/labs/lab-01
```

Finish with the final submit command in the walkthrough. It deletes the lab.
To abandon an attempt, use `astrona destroy ats-020-lab-010-03`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, bootstrap, reference solution and grading |
| `prerequisites.md` | Skills and terminal requirements |
| `question.md` | Exam-style task |
| `solution.md` | Walkthrough and watch feedback |
| `bootstrap/` | Stack installation and starting-state preparation |
| `manifests/` | Workloads, maintenance fixture and wrong route |
| `solution/` | Reference rule, route and silence command |
| `testing/` | Bounded wait for reference webhook delivery |
| `validation/` | Four checks against live component APIs and receiver logs |

Built without booting on 2026-11-06. Use `astrona validate -c sections/section-010/module-30/labs/lab-01` for offline structure checks.
Runtime behavior and reference-solution success still require a future lab run.

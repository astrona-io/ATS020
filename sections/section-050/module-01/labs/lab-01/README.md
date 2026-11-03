---
estimated_duration: 40m
---

# Fix Four Failing Workloads Lab

- **Slug:** ats-020-lab-050-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8 with the metrics-server
add-on. The namespace `starfleet` holds a healthy `shuttle` client and four
broken Deployments: `scout` is Pending, `probe` is restarted by its liveness
probe, `cargo` is OOMKilled and `beacon` is in ImagePullBackOff. The learner
finds each cause, fixes it, and proves the fix with a `200` from `shuttle`.
No Prometheus stack runs.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-01/labs/lab-01
astrona submit -c sections/section-050/module-01/labs/lab-01
astrona destroy ats-020-lab-050-01
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
| `bootstrap/01-prepare.sh` | Waits until metrics-server answers |
| `manifests/lab-start.yaml` | The namespace, `shuttle` and the four Services |
| `manifests/faults-start.yaml` | The four broken Deployments (the faults are the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-pods.sh` | Waits for ready pods before grading in tests |
| `validation/` | One script per check |

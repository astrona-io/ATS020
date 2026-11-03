---
estimated_duration: 45m
---

# Incident Response Capstone

- **Slug:** ats-020-capstone-050
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8 with the metrics-server
add-on. After a release the namespace `starfleet` has three broken workloads
and an admission webhook that blocks every create of a Deployment. `cargo` is
OOMKilled, `beacon` is in ImagePullBackOff, `probe` is restarted by its liveness
probe, and the Service of the `starfleet-policy` webhook selects no pod. The
learner finds each cause, fixes it, and proves the recovery with a `200` from
`shuttle` and a create that the webhook answers.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/capstone/labs/lab-01
astrona submit -c sections/section-050/capstone/labs/lab-01
astrona destroy ats-020-capstone-050
```

Authors run a local copy with `astrona run -c .` and prove the reference
solution with `astrona test -c .`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition |
| `prerequisites.md` | What the learner needs first |
| `question.md` | The task |
| `solution.md` | The walkthrough |
| `bootstrap/01-prepare.sh` | Waits until metrics-server answers |
| `manifests/lab-start.yaml` | The workloads, the webhook server and its configuration, with the four faults |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-platform.sh` | Waits for ready pods before grading in tests |
| `validation/` | One script per check |

---
estimated_duration: 45m
---

# Platform Efficiency Capstone

- **Slug:** ats-020-capstone-040
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8 with Argo CD, Gitea,
metrics-server and a trimmed kube-prometheus-stack 92.3.0. The Application
`scout` has ten backdated deployments, two of them with a missing image tag.
The pod `shuttle` makes about 5% of the requests to `scout` fail. The
Deployment `beacon` requests far more than it uses. The learner writes the
recording rules and the burn-rate alert for DORA and SLO numbers, and
right-sizes `beacon`.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/capstone/labs/lab-01
astrona submit -c sections/section-040/capstone/labs/lab-01
astrona destroy ats-020-capstone-040
```

Authors run a local copy with `astrona run -c . --trust` and prove the
reference solution with `astrona test -c . --accept-terms`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition |
| `prerequisites.md` | What the learner needs first |
| `question.md` | The task |
| `solution.md` | The walkthrough |
| `bootstrap/01-prepare.sh` | Installs Argo CD, Gitea and the Prometheus stack and replays the history |
| `manifests/lab-start.yaml` | `scout` monitor, `shuttle` and `beacon` |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-solution.sh` | Waits for the rules to load |
| `validation/` | One script per check |

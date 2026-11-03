---
estimated_duration: 20m
---

# Fix A Broken Collector Pipeline Lab

- **Slug:** ats-020-lab-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs
cert-manager 1.21.2 and the OpenTelemetry Operator 0.160.0, then applies
Jaeger 2.22.0, the `scout` workload with tracing on, a `shuttle` traffic
client and a Collector named `otel` that is `Running` but broken. The learner
finds the two faults in its exporter and proves the fix with the Collector
counters and the Jaeger API.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/labs/lab-01
astrona submit -c sections/section-030/module-01/labs/lab-01
astrona destroy ats-020-lab-030-01
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
| `bootstrap/01-install-operator.sh` | Installs cert-manager and the Operator |
| `manifests/lab-start.yaml` | Jaeger, `scout` and `shuttle` |
| `manifests/collector-start.yaml` | The broken Collector (the fault is the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-pipeline.sh` | Waits for spans before grading in tests |
| `validation/` | One script per check |

---
estimated_duration: 60m
---

# Distributed Tracing Capstone

- **Slug:** ats-020-capstone-030
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs
cert-manager 1.21.3 and the OpenTelemetry Operator 0.162.0, then applies
Jaeger 2.22.0, the `scout` workload with tracing on but a wrong exporter port,
a `shuttle` traffic client and the `relay` workload with no instrumentation.
No Collector exists. The learner writes the Collector and the Instrumentation,
fixes the exporter of `scout`, instruments `relay`, and names the slow call
after reading Jaeger.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/capstone/labs/lab-01
astrona submit -c sections/section-030/capstone/labs/lab-01
astrona destroy ats-020-capstone-030
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
| `manifests/lab-start.yaml` | Jaeger, `scout` (with the wrong exporter port), `relay` and `shuttle` |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-traces.sh` | Waits for spans of `relay` before grading in tests |
| `validation/` | One script per check |

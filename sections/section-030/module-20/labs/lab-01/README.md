---
estimated_duration: 30m
---

# Get Two Services Into One Trace Lab

- **Slug:** ats-020-lab-030-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs
cert-manager 1.21.2 and the OpenTelemetry Operator 0.160.0, then applies
Jaeger 2.22.0, a working Collector `otel`, the `scout` workload with tracing
on, a `shuttle` traffic client and the `relay` workload. `relay` is meant to
be auto-instrumented but is not. The learner finds the three faults and proves
the fix with a trace in Jaeger that has spans from both `relay` and `scout`.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-20/labs/lab-01
astrona submit -c sections/section-030/module-20/labs/lab-01
astrona destroy ats-020-lab-030-02
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
| `manifests/lab-start.yaml` | Jaeger, the Collector, `scout`, the `relay` ConfigMap and Service, and `shuttle` |
| `manifests/relay-start.yaml` | The `relay` Deployment and the Instrumentation, with three faults (the fault is the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-traces.sh` | Waits for spans of `relay` before grading in tests |
| `validation/` | One script per check |

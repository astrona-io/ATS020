---
estimated_duration: 20m
---

# Fix A Broken Collector Pipeline Lab

- **Slug:** ats-020-lab-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

A single-node kind cluster running Kubernetes 1.35.8. The bootstrap installs
cert-manager 1.21.3 and the OpenTelemetry Operator 0.162.0, then applies
Jaeger 2.23.0, the `scout` workload with tracing on, a `shuttle` traffic
client and a Collector named `otel` that is `Running` but broken. The learner
finds the two faults in its exporter and proves the fix with the Collector
counters and the Jaeger API.

The browser workspace has four tabs next to the main terminal: **Jaeger**
(port forward `jaeger-ui`, `127.0.0.1:26686` to `svc/jaeger:16686`),
**Collector metrics** (port forward `collector-metrics`, `127.0.0.1:28888` to
`svc/otel-collector-monitoring:8888`), **Logs** (a second terminal) and
**Collector reference** (`docs/collector-reference.md`). The host ports are
not the services' own ports, so a local Jaeger or Collector does not block
them.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-10/labs/lab-01
astrona submit -c sections/section-030/module-10/labs/lab-01
astrona destroy ats-020-lab-030-01
```

Authors run a local copy with `astrona run -c .` and prove the reference
solution with `astrona test -c .`.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition |
| `prerequisites.md` | What the learner needs first |
| `docs/collector-reference.md` | Collector reference shown on the workspace's **Collector reference** tab |
| `question.md` | The task |
| `solution.md` | The walkthrough with real output |
| `bootstrap/01-install-operator.sh` | Installs cert-manager and the Operator |
| `manifests/lab-start.yaml` | Jaeger, `scout` and `shuttle` |
| `manifests/collector-start.yaml` | The broken Collector (the fault is the material) |
| `solution/` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-pipeline.sh` | Waits for spans before grading in tests |
| `validation/` | One script per check |

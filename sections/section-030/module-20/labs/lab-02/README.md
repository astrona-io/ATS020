---
estimated_duration: 15m
---

# Identify the Slow Operation in a Trace Lab

Four tasks take about 15 minutes, plus cluster startup and span export time. The lab starts with working Node.js auto-instrumentation and context propagation. The learner exports one complete slow trace and identifies its delayed internal operation. Two graders check the exported parent chain against Jaeger and the finding against the saved timestamps.

The environment name is `ats-020-lab-030-02-02`. It uses the same pinned Kubernetes, Operator, Collector, Jaeger, and application versions as the module playground.

## Run and test

From this directory, start a local copy:

```sh
astrona run -c .
```

Run the reference solution and graders on a disposable cluster:

```sh
astrona validate -c .
astrona test -c .
```

Run the grader's failure cases without a cluster:

```sh
python3 testing/test-validation.py
```

The tests cover missing evidence, incomplete and disconnected traces, modified timestamps, duplicate spans, unavailable Jaeger, incorrect identifiers, and selection of an enclosing request instead of the internal handler.

## Evidence files

The learner and reference solution write `/tmp/ats020-slow-trace.json` and `/tmp/ats020-slow-span.json`. These are local files read by the graders. The first contains exactly one Jaeger v3 trace response; the second contains the service, operation name, trace ID, span ID, and rounded duration in milliseconds.

The trace grader reads Jaeger through the Kubernetes API server proxy, so grading does not depend on a learner's port-forward. It verifies the saved spans' identities, names, kinds, parent links, and timestamps against the stored trace. Neither grader changes the cluster or evidence files.

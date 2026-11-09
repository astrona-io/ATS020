---
estimated_duration: 10m
---

# Restore Trace Context Propagation Lab

Four tasks, about 10 minutes of learner work, plus cluster startup and span export time. The agent is injected and exports spans, but only baggage propagation is enabled. The learner restores tracecontext and replaces the pod.

The independent environment is `ats-020-lab-030-02-04`. The cluster, Collector, backend, and traffic generator are supplied, so the learner works on one tracing problem.

## Run and test

From this directory:

```sh
astrona run -c .
astrona submit -c .
```

Authors can validate the configuration and run the reference solution on a disposable cluster:

```sh
astrona validate -c .
astrona test -c .
```

The test first checks the intended starting fault, then applies the reference solution and runs the graders. Each grader reports its own failure so a failed configuration check can be distinguished from delayed trace export. Validation never changes the cluster.

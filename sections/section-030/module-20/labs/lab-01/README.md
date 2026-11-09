---
estimated_duration: 15m
---

# Repair Missing Agent Injection Lab

Four tasks, about 15 minutes of learner work, plus cluster startup and span export time. The annotation is misplaced and its namespace selection is wrong. The exporter, propagators, and sampler already work.

The independent environment is `ats-020-lab-030-02`. The cluster, Collector, backend, and traffic generator are supplied, so the learner works on one tracing problem.

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

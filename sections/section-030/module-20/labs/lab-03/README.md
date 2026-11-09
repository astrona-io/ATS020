---
estimated_duration: 10m
---

# Enable Node.js Agent Injection Lab

Four tasks, about 10 minutes of learner work, plus cluster startup and span export time. No Instrumentation or injection annotation exists yet. The learner creates the settings and requests injection.

The independent environment is `ats-020-lab-030-02-03`. The cluster, Collector, backend, and traffic generator are supplied, so the learner works on one tracing problem.

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

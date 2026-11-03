---
estimated_duration: 20m
---

# Count Error Log Lines With The OpenTelemetry Collector

Graded lab for the pod logs module. A Collector DaemonSet reads the container log files and counts the `probe` error lines into the metric `log_error_lines_total`, but Prometheus shows no usable series. The learner finds two faults: the Collector's service account has no permission to list pods, and the ServiceMonitor lacks the label the Prometheus resource selects. The grader checks that the target is up, that the metric carries the `outpost` and `probe` labels and keeps rising, and that the fix did not widen the Collector's permissions or remove a processor.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-02/labs/lab-01
astrona submit -c sections/section-020/module-02/labs/lab-01
astrona destroy ats-020-lab-020-02
```

Authors can run the reference solution with `astrona test -c sections/section-020/module-02/labs/lab-01`.

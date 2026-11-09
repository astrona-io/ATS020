---
estimated_duration: 15m
---

# Scrape Pods With A PodMonitor

The `scout` Pods in `outpost` expose metrics without a Service. Prometheus does not yet scrape them.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-10/labs/lab-04
astrona submit -c sections/section-010/module-10/labs/lab-04
astrona destroy ats-020-lab-010-01-04
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

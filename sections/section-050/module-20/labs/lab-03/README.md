---
estimated_duration: 15m
---

# Restore The Prometheus Operator

Prometheus runs, but it does not scrape `scout` or load `ScoutDown`. The Prometheus Operator Deployment `kps-operator` in `monitoring` has stopped.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-20/labs/lab-03
astrona submit -c sections/section-050/module-20/labs/lab-03
astrona destroy ats-020-lab-050-02-03
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

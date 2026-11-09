---
estimated_duration: 15m
---

# Measure Deployment Frequency

Argo CD has synced ten revisions of `scout`. The recording rule selects failed sync operations, so it does not count the deployments.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-10/labs/lab-02
astrona submit -c sections/section-040/module-10/labs/lab-02
astrona destroy ats-020-lab-040-01-02
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

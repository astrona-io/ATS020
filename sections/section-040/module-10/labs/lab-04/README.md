---
estimated_duration: 15m
---

# Measure Time To Restore Service

The lab creates ten real Git revisions and Argo CD deployments, including two failed builds and their reverts. Startup includes this history generation.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-10/labs/lab-04
astrona submit -c sections/section-040/module-10/labs/lab-04
astrona destroy ats-020-lab-040-01-04
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

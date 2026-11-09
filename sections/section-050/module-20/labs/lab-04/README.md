---
estimated_duration: 15m
---

# Recover A GitOps Source Path

The `scout` Application reports a comparison error after its source path changed. The last successfully deployed workload still runs.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-20/labs/lab-04
astrona submit -c sections/section-050/module-20/labs/lab-04
astrona destroy ats-020-lab-050-02-04
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

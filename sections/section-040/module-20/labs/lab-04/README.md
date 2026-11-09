---
estimated_duration: 15m
---

# Record Availability And Error Budget

Traffic to `scout` includes HTTP 500 responses. Create recording rules that measure availability and the remaining budget for a 99% objective.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-20/labs/lab-04
astrona submit -c sections/section-040/module-20/labs/lab-04
astrona destroy ats-020-lab-040-02-04
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

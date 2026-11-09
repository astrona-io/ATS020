---
estimated_duration: 15m
---

# Repair Route Precedence And Grouping

Two warning alerts differ by Pod. A route stops after the first matching child and groups each Pod separately, so the archive receiver is skipped and notifications are split.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-30/labs/lab-05
astrona submit -c sections/section-010/module-30/labs/lab-05
astrona destroy ats-020-lab-010-03-05
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

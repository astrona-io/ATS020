---
estimated_duration: 15m
---

# Repair An Error Ratio Recording Rule

The recording rule `scout:error_ratio:rate5m` in `monitoring/scout-queries` returns the wrong result. The other recording rule is already correct.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-20/labs/lab-02
astrona submit -c sections/section-010/module-20/labs/lab-02
astrona destroy ats-020-lab-010-02
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

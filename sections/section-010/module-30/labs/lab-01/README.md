---
estimated_duration: 15m
---

# Create And Verify An Alerting Rule

Traffic to `scout` includes status `500` responses. Its alerting rule is missing; the receiver route already works.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-30/labs/lab-01
astrona submit -c sections/section-010/module-30/labs/lab-01
astrona destroy ats-020-lab-010-03
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

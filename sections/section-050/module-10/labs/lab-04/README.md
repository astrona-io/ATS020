---
estimated_duration: 15m
---

# Repair An Image Reference

The `beacon` Deployment in `starfleet` is unhealthy. The `shuttle` client and the Service `beacon` are available for testing.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-10/labs/lab-04
astrona submit -c sections/section-050/module-10/labs/lab-04
astrona destroy ats-020-lab-050-01-04
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

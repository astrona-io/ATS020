---
estimated_duration: 15m
---

# Raise An Undersized Memory Request

The `probe` Deployment in `starfleet` has a resource request that does not match its usage. The other workload starts with suitable requests.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-20/labs/lab-03
astrona submit -c sections/section-040/module-20/labs/lab-03
astrona destroy ats-020-lab-040-02-03
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

---
estimated_duration: 15m
---

# Reduce Excess Resource Requests

The `scout` Deployment in `starfleet` has a resource request that does not match its usage. The other workload starts with suitable requests.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-20/labs/lab-02
astrona submit -c sections/section-040/module-20/labs/lab-02
astrona destroy ats-020-lab-040-02-02
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

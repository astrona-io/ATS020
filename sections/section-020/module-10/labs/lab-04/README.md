---
estimated_duration: 15m
---

# Repair Grafana Secret Keys

Grafana was moved to `telemetry`. One startup fault remains; the other settings already allow it to run. The Service `grafana` listens on port `3000`.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-10/labs/lab-04
astrona submit -c sections/section-020/module-10/labs/lab-04
astrona destroy ats-020-lab-020-01-04
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

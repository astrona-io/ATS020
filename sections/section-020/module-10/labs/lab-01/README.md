---
estimated_duration: 15m
---

# Restore Dashboard Provisioning

The team stores `Scout Overview` (UID `scout-overview`) in `monitoring/dashboard-scout-overview`. Grafana uses the provisioned Prometheus data source (UID `prometheus`).

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-10/labs/lab-01
astrona submit -c sections/section-020/module-10/labs/lab-01
astrona destroy ats-020-lab-020-01
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

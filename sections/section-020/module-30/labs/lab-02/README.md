---
estimated_duration: 15m
---

# Find And Stop Error-Logging Workloads

Loki stores logs with `namespace`, `pod` and `container` labels. Grafana has the editable `loki` data source and the saved `outpost-logs` dashboard.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-30/labs/lab-02
astrona submit -c sections/section-020/module-30/labs/lab-02
astrona destroy ats-020-lab-020-03-02
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

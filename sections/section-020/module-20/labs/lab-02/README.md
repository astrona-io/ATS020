---
estimated_duration: 15m
---

# Scrape Collector Error Metrics

The `logs` Collector runs as a DaemonSet in `monitoring`. It reads `probe` error logs and exposes `log_error_lines_total` for Prometheus.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-20/labs/lab-02
astrona submit -c sections/section-020/module-20/labs/lab-02
astrona destroy ats-020-lab-020-02-02
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

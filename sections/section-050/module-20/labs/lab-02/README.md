---
estimated_duration: 15m
---

# Renew An Expired Webhook Certificate

The `outpost-policy` admission webhook blocks Deployment creation in `outpost`. Its server and Service run in `webhook-system`.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-20/labs/lab-02
astrona submit -c sections/section-050/module-20/labs/lab-02
astrona destroy ats-020-lab-050-02-02
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

---
estimated_duration: 15m
---

# Route An Alert To Its Receiver

`ScoutErrorRate` is already installed. The AlertmanagerConfig `starfleet/scout-routing` matches the wrong team, so the webhook receives no notification.

This independent lab has four tasks. Allow 10–15 minutes for task work, plus cluster startup and telemetry collection.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-30/labs/lab-02
astrona submit -c sections/section-010/module-30/labs/lab-02
astrona destroy ats-020-lab-010-03-02
```

Authors run `astrona validate` and `astrona test` with the same configuration path. The lifecycle test checks the starting fault before applying the reference solution. GitHub Actions discovers this lab automatically.

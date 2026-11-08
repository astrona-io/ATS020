---
estimated_duration: 25m
---
# Bring Grafana Back After A Namespace Move Lab

- **Slug:** ats-020-lab-020-01-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

Grafana 13.2.3 was moved from `monitoring` to the new namespace `telemetry`
and does not start. Three faults stop it, one after the other: the data
directory is a ConfigMap volume whose ConfigMap does not exist, the admin
password reads a Secret key the new Secret lacks, and the memory limit is
`32Mi`. The learner may change only resource requests and limits, Secrets,
volumes and volumeMounts. The grader checks the rollout, the health endpoint,
a login with basic authentication and that nothing outside the allowed
changes moved. No Helm chart is installed; the lab starts in about a minute.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-10/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-10/labs/lab-02
astrona destroy ats-020-lab-020-01-02
```

The terminal needs kubectl, curl and jq.

Author status: built without booting on 2026-11-07. Runtime behaviour remains untested.

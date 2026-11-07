---
estimated_duration: 20m
---

# Export The Exceptions Of A Failed Trace Lab

- **Slug:** ats-020-lab-030-01-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

Three small Python workloads in `starfleet` send synthetic spans to Jaeger
2.22.0 in `observability`. One workload, `probe`, calls an address whose
Service does not exist, so every one of its spans ends with the status `ERROR`
and carries a span event named `exception`. The learner finds that service in
Jaeger, writes its name to `/tmp/ats-020-error-service.txt`, exports the
`exception` events of its spans as a JSON array to
`/tmp/ats-020-exceptions.json`, and repairs the environment variable
`TARGET_URL` so that the new pod's traces have no error.

The fixture sends OpenTelemetry Protocol JSON directly to Jaeger. No Operator,
Collector or Python packages are needed. Jaeger stores traces in memory, so a
backend restart removes export evidence. The terminal needs kubectl, curl and jq.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/labs/lab-03
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/labs/lab-03
astrona destroy ats-020-lab-030-01-03
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, bootstrap and grading |
| `prerequisites.md` | Terminal tools and prior knowledge |
| `question.md` | Search, export and repair task |
| `solution.md` | Walkthrough with observations to look for |
| `bootstrap/01-prepare.sh` | Check terminal tools and remove old answer files |
| `manifests/lab-start.yaml` | Backend, two healthy emitters and one emitter with error spans |
| `solution/apply.sh` | Reference solution |
| `testing/wait-for-traces.sh` | Wait for an exception event before the reference solution runs |
| `validation/` | Answer file, exported events and live trace checks |

Built without booting on 2026-11-07. Runtime behavior is untested.

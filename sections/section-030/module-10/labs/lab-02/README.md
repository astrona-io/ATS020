---
estimated_duration: 20m
---

# Find Tagged Traces And Remediate Deployments Lab

- **Slug:** ats-020-lab-030-01-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona lab, graded

Three small Python workloads in `starfleet` send synthetic spans to Jaeger
2.23.0 in `observability`. Each workload has a distinct `incident.code` span
tag. The learner searches by tag, changes one Deployment environment variable,
scales another Deployment and exports five complete traces as JSON to
`/tmp/ats-020-incident-traces.json`. Jaeger 2.23.0 serves only the `/api/v3`
search API, so the grader counts distinct `traceId` values in its response.

The fixture sends OpenTelemetry Protocol JSON directly to Jaeger. No Operator,
Collector or Python packages are needed. Jaeger stores traces in memory, so a
backend restart removes export evidence. The terminal needs kubectl, curl and jq.

## Run it

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-10/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-10/labs/lab-02
astrona destroy ats-020-lab-030-01-02
```

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Runtime, bootstrap and grading |
| `prerequisites.md` | Terminal tools and prior knowledge |
| `question.md` | Search, remediation and export task |
| `solution.md` | Walkthrough with observations to look for |
| `bootstrap/01-prepare.sh` | Check terminal tools and remove an old export file |
| `manifests/lab-start.yaml` | Backend and tagged trace emitters |
| `solution/apply.sh` | Reference solution |
| `testing/wait-for-traces.sh` | Wait for trace evidence before the reference solution runs |
| `validation/` | Deployment, file shape and live trace checks |

Built without booting on 2026-11-04. Runtime behavior is untested.

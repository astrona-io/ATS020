# ATS020 — Observability and Operations (Certified Cloud Native Platform Engineer)

[![Liberapay](https://img.shields.io/badge/Liberapay-Support_Astrona.io-F6C915?logo=liberapay&logoColor=black&style=for-the-badge)](https://liberapay.com/Astrona.io)

Hands-on course for the Observability and Operations domain of the Certified Cloud Native Platform Engineer (CNPE) exam. The reader learns to get workload metrics into Prometheus, query them with PromQL, alert on them through Alertmanager, show them in Grafana, collect pod logs with the OpenTelemetry Collector and turn them into metrics, trace requests with OpenTelemetry and Jaeger, measure delivery and resource efficiency of the platform, and diagnose and fix broken workloads and platform components on a live cluster. Breadth over depth, as the exam expects: each tool is taught to the level of one working task, proved with a query, a trace or a real request.

This course covers the **Observability and Operations** domain of the Certified Cloud Native Platform Engineer (CNPE) exam, **20% of the exam**.

Everything lives under `sections/`. Each section is a set of modules, and each module is:

- a **landing page** (`course-000.md`) plus, where the subject needs it, ordered **lessons** (`course-0N0-*.md`) with runnable examples and short diagrams;
- an ungraded **playground** for the reading examples;
- independent **module labs** immediately after their preparation lessons, each with 3–5 tasks and 10–15 minutes of task work. Startup and telemetry collection add time;
- a **summary** (`course-100-summary.md`) that connects outcomes with verification evidence.

Each section ends with a **capstone lab** combining its modules and a knowledge-check quiz.

[`astrona.yaml`](astrona.yaml) is the manifest: every section, module, reading, playground, lab and capstone in the order they are meant to be taken.

Everything targets **kind v0.33.0**, **kubernetes 1.35**, **kind_node_image kindest/node:v1.35.8**, **kube_prometheus_stack_chart 92.22.0**, **metrics_server 0.9.0**, **grafana 13.2.3**, **opentelemetry_operator 0.162.0**, **opentelemetry_collector 0.165.0**, **jaeger 2.23.0**, **cert_manager 1.21.3**, **argo_cd 3.6.1**, **flux 2.9.6**, **gitea 28.3.0**, **helm 4.3.1**, **podinfo 6.17.0**, **go_httpbin 2.25.0** on `kind`.

---

## Sections

| Section | Title | Modules | Curriculum item |
| --- | --- | --- | --- |
| [010](sections/section-010) | Metrics And Alerting With Prometheus | 3 | Implementing Monitoring, Alerting, Logging, and Tracing Solutions |
| [020](sections/section-020) | Dashboards And Logs | 3 | Implementing Monitoring, Alerting, Logging, and Tracing Solutions |
| [030](sections/section-030) | Distributed Tracing With OpenTelemetry And Jaeger | 2 | Implementing Monitoring, Alerting, Logging, and Tracing Solutions |
| [040](sections/section-040) | Measuring Platform Efficiency | 2 | Measuring and Improving Platform Efficiency Using Deployment Metrics and Performance Indicators |
| [050](sections/section-050) | Diagnosing And Remediating Incidents | 2 | Diagnosing and Remediating Platform Issue and Incident Scenarios |

---

## How to work through it

1. Open the section's `README.md` for the map.
2. Read each module's `course-000.md`, then its deep-dive parts in order.
3. Start the module playground and run the reading examples.
4. Pause it for each independent lab, complete the tasks, submit, then remove the lab and resume reading.
5. Solve the section capstone without looking at the walkthrough.
6. Take the section quiz, then the final domain quiz once every section is done.

---

## Support This Project

ATS020 is free training material. If it helped you, consider supporting ongoing work via [Liberapay](https://liberapay.com/Astrona.io).

## Authoring and automatic checks

`CLAUDE.md` records this course's authoring rules. The reusable `focused-course-labs` skill is maintained in `skills/focused-course-labs/SKILL.md`.

GitHub Actions discovers every lab configuration. It checks course structure, runs grader regression tests, validates each lab, and tests its starting state and reference solution in a fresh cluster. The required `all environments pass` check depends on every selected environment.

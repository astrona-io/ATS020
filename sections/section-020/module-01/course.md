# Build Grafana Dashboards As Code

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Add a Prometheus data source to Grafana with a provisioning file or a labelled ConfigMap
- Build a panel from a PromQL query and choose the right visualisation for a rate, a ratio and a latency
- Use a dashboard variable to switch the namespace shown on every panel
- Export a dashboard as JSON and load it through the Grafana sidecar ConfigMap so it survives a pod restart

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Grafana's parts — data source, dashboard, panel, query, variable
- Provisioning — data sources and dashboards from files and ConfigMaps, and why click-built dashboards are lost
- Building panels for request rate, error ratio and latency
- Variables and templating

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — ConfigMap with dashboard label, Grafana sidecar loads it, panel queries Prometheus data source -->

<!-- playground provides: Trimmed kube-prometheus-stack with Prometheus and Grafana on (default dashboards off, sidecar for dashboards and data sources on, admin password set and shown in the playground guide). ServiceMonitors for `scout` and `probe` applied, traffic loop running. No Starfleet dashboard exists yet. Port-forward to Grafana on 3000 documented. -->

<!-- module section-020/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

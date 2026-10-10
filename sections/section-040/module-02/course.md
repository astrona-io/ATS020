# Measure Service Levels And Resource Efficiency

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Write an SLI as a PromQL ratio of good requests to all requests
- Calculate the remaining error budget for a 99% SLO over a window
- Write a burn-rate alert that fires when the budget would run out early
- Compare container CPU and memory requests with real usage from metrics-server and Prometheus
- Name the workload with the biggest gap and change its requests to match usage

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- SLI, SLO and error budget, with a worked example on `probe`
- Burn rate and multi-window alerts
- Requests versus usage — `kubectl top`, container metrics and kube-state-metrics
- Right-sizing one workload and proving the waste went down

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — Good and total request counters, SLI ratio, SLO target, remaining error budget, burn-rate alert -->

<!-- playground provides: kind cluster with metrics-server 0.9.0 and trimmed kube-prometheus-stack with kube-state-metrics on (needed for requests). `probe` serves a fixed share of 500 responses so the SLI is below target and the error budget is burning. `scout` requests far more CPU and memory than it uses, and a third Deployment requests too little, so both directions of the gap are visible. -->

<!-- module section-040/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

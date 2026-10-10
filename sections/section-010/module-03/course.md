# Alert With PrometheusRule And Alertmanager

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-03/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Write an alerting rule in a PrometheusRule with `expr`, `for`, labels and annotations
- Write a recording rule and query the new series it creates
- Read an alert's state (inactive, pending, firing) in Prometheus and in Alertmanager
- Route alerts by label to a receiver with an AlertmanagerConfig or the Alertmanager configuration
- Silence an alert for a time window and prove it stops notifying

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Recording rules versus alerting rules, and how the operator picks up a PrometheusRule (ruleSelector)
- The alert lifecycle — inactive, pending for `for:`, firing, resolved
- Alertmanager routing tree, grouping and receivers
- Silences and inhibition

## Diagrams planned

<!-- TODO(build): mermaid `state` — Alert lifecycle from inactive to pending to firing to resolved -->
<!-- TODO(build): mermaid `flowchart` — Prometheus evaluates rule, sends alert to Alertmanager, route tree matches labels, receiver gets notification -->

<!-- playground provides: Trimmed kube-prometheus-stack with Prometheus and Alertmanager on, ServiceMonitors for `scout` and `probe` applied, and a webhook receiver pod in namespace `monitoring` (a small HTTP echo that logs every POST) so the reader can see notifications arrive. No PrometheusRule for the Starfleet app exists yet. `probe` can be made to fail on demand by pointing the traffic loop at `/status/500`. -->

<!-- module section-010/module-03 (Module 3) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

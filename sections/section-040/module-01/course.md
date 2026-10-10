# Measure Delivery With DORA Metrics

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-040/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Define deployment frequency, lead time for changes, change failure rate and time to restore service
- Count deployments over a time window from the GitOps controller's sync metrics in Prometheus
- Calculate lead time from a commit time in Git and the sync time recorded by the controller
- Calculate change failure rate and time to restore from failed and recovered deployments
- Name one change to the delivery process that improves each metric

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- The four DORA metrics and what each one says about a platform
- Where the data comes from — Git history, the GitOps controller's sync history and its Prometheus metrics
- Queries for deployment frequency and change failure rate
- Lead time and time to restore from timestamps

## Diagrams planned

<!-- TODO(build): mermaid `timeline` — Commit, sync, healthy, failure, rollback — the timestamps each DORA metric is measured between -->
<!-- TODO(build): mermaid `flowchart` — Gitea commit, Argo CD sync, metrics in Prometheus, DORA queries -->

<!-- playground provides: kind cluster with Gitea 28.1.0 holding a `starfleet-deploy` repository, Argo CD 3.5.4 with an Application for `scout` in `starfleet`, and trimmed Prometheus scraping Argo CD's metrics. A seed script makes a history of about ten commits and syncs, two of them deliberately bad (failing image tag) and later rolled back, so the queries have data. Flux is not installed. Heaviest playground in the course; nothing else runs beside it. -->

<!-- module section-040/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

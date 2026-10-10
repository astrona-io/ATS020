# Diagnose And Fix Broken Platform Components

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Find a failing admission webhook from the API server error message and fix its Service without deleting it
- Find an expired webhook serving certificate from the `x509` error text and `openssl`, and replace it
- Find a stopped or crashing controller from its Deployment, logs and the resources that stop reconciling
- Find why a GitOps Application is stuck OutOfSync or Degraded from its status conditions and fix the cause in Git
- Prove each fix by the platform behaviour it restores (create succeeds, resource reconciles, sync is Healthy)

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- How platform components fail differently from workloads — the symptom shows up somewhere else
- Admission webhooks — failurePolicy, the error text, and the Service behind it
- Controllers — reconcile loops that stop, leader election, status conditions
- GitOps sync failures — OutOfSync, Degraded, sync errors
- Certificates — the serving certificate behind a webhook, its expiry, and the `caBundle` the API server trusts

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — kubectl create, API server calls webhook, webhook Service has no endpoints, request is rejected -->
<!-- TODO(build): mermaid `flowchart` — Symptom to component to the status field that names the cause -->

<!-- playground provides: kind cluster with Argo CD with an Application backed by an in-cluster Git repository (Gitea as plumbing), a trimmed Prometheus stack, and two small validating webhooks. Starts broken on purpose: one webhook's Service selector matches no pod (creates in `starfleet` fail), the other webhook serves an expired certificate (creates in `outpost` fail with an `x509` error), the Prometheus Operator is scaled to zero so a new PrometheusRule never reaches Prometheus, and the Application points at a path that does not exist so it is stuck. Each fault is independent so the reader can fix them in any order. -->

<!-- module section-050/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

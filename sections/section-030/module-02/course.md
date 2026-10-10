# Add Tracing Without Code Changes Using Auto-Instrumentation

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Write an Instrumentation resource with the exporter endpoint, propagators and sampler
- Annotate a Deployment so the operator injects the language agent, and restart it so the change takes effect
- Read the injected init container and environment variables to prove injection happened
- Follow one request across two services in Jaeger and name the slowest span
- Find why a pod was not instrumented (annotation on the wrong object, Instrumentation in another namespace, pod not restarted)

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- What auto-instrumentation injects and when (pod creation, mutating webhook)
- The Instrumentation resource — exporter, propagators, sampler, language blocks
- Annotations and restarts
- Reading a two-service trace and finding the slow step

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — Pod create request, operator webhook adds init container and env, app starts with agent, spans exported -->

<!-- playground provides: kind cluster with cert-manager, OpenTelemetry Operator 0.160.0, a working Collector exporting to Jaeger 2.22.0. A `relay` Node.js service (node:22-alpine with a small HTTP server script from a ConfigMap) in `starfleet` that calls `scout`; `relay` has no instrumentation and no annotation yet. `scout` exports its own spans, so once `relay` is instrumented the reader sees one trace with spans from both. -->

<!-- module section-030/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

# Triage And Fix Failing Workloads

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-050/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Follow a fixed triage order — status, events, describe, logs, previous logs — to find a pod's failure cause
- Fix a Pending pod caused by too-large requests, a missing PersistentVolumeClaim or an unmatched node selector
- Fix a CrashLoopBackOff caused by a bad command, a missing ConfigMap key or a failing liveness probe
- Fix an OOMKilled container by reading its usage and setting a fitting memory limit
- Fix an ImagePullBackOff caused by a wrong tag or a missing pull secret

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- A triage order and the commands for each step
- Pending — scheduler events and what they say
- CrashLoopBackOff and probes — exit codes, previous logs
- OOMKilled — last state, memory limits and usage
- ImagePullBackOff — image references and pull secrets

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — Decision tree from pod status to the command that shows the cause to the usual fix -->
<!-- TODO(build): mermaid `state` — Pod and container states — Pending, ContainerCreating, Running, CrashLoopBackOff, Terminated OOMKilled -->

<!-- playground provides: kind cluster with metrics-server, starts broken on purpose: in `starfleet`, one Deployment per failure kind — `scout` Pending (requests more CPU than the node has), `probe` in CrashLoopBackOff (liveness probe on a wrong path), a `cargo` Deployment OOMKilled (memory limit below its working set), and `beacon` in ImagePullBackOff (tag that does not exist). `shuttle` is healthy and used to prove each fix with a request. No monitoring stack needed. -->

<!-- module section-050/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

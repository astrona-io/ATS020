# Run An OpenTelemetry Collector With The Operator

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Install the OpenTelemetry Operator after cert-manager and confirm its webhook is ready
- Write an OpenTelemetryCollector resource with an OTLP receiver, a batch processor and an exporter to Jaeger
- Choose the Collector mode (deployment, daemonset, sidecar) for a given need
- Send a test trace over OTLP and find it in the Jaeger UI and API
- Diagnose a broken pipeline from the Collector's logs (wrong endpoint, missing pipeline, unused receiver)

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- Traces and spans, trace IDs and context propagation through the `traceparent` header
- The OpenTelemetry Operator and its OpenTelemetryCollector resource
- Receivers, processors, exporters and pipelines for traces
- Jaeger 2 as the trace backend, and reading a trace in its UI

## Diagrams planned

<!-- TODO(build): mermaid `sequence` — A request crosses two services, each creates a span with the same trace ID and exports it over OTLP -->
<!-- TODO(build): mermaid `flowchart` — App, OTLP receiver, batch processor, OTLP exporter, Jaeger, UI -->

<!-- playground provides: kind cluster with cert-manager 1.21.2 and Jaeger 2.22.0 (all-in-one, in-memory storage, OTLP on 4317 and 4318, UI on 16686) in namespace `observability`. The OpenTelemetry Operator is not installed yet, so the reader installs it. `scout` in `starfleet` configured to export traces over OTLP to a Collector Service name that does not exist yet, so no traces appear until the Collector is created. No Prometheus stack, to save memory. -->

<!-- module section-030/module-01 (Module 1) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

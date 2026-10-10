# Collect Pod Logs With The OpenTelemetry Collector

<!-- astrona:playground -->
> [!NOTE]
> This module has a playground — a throwaway environment to run the commands in.
> ```bash
> astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-02/playground
> ```

<!-- TODO(build): opening framing — what this module settles, and the contrast that sharpens its boundary. -->

## Learning objectives

- Read a pod's logs, its previous container's logs and its events with `kubectl logs` and `kubectl events`
- Deploy an OpenTelemetry Collector as a DaemonSet whose filelog receiver reads the container log files on each node
- Add Kubernetes metadata to each log record with the k8sattributes processor and drop unwanted records with the filter processor
- Check the logs pipeline end to end with the debug exporter and the Collector's own logs
- Turn error log lines into a Prometheus metric with the count connector and query it with PromQL

## Before you start

<!-- TODO(build): assumed knowledge, and what the playground already provides. -->

## Outline

<!-- TODO(build): each beat below becomes a section of this module (or a deep-dive part via /astrona-course-deep-dive). Delete this Outline section once written. -->

- What Kubernetes keeps on its own — `kubectl logs`, `--previous`, events — and why a cluster still needs a log pipeline
- Where container logs live on a node and why a DaemonSet reads them
- Collector configuration for logs — filelog receiver, container parser, k8sattributes and filter processors, debug exporter
- From log lines to a metric — the count connector and a Prometheus exporter scraped by Prometheus

## Diagrams planned

<!-- TODO(build): mermaid `flowchart` — Container stdout to node log file, filelog receiver, k8sattributes and filter processors, debug exporter and count connector to Prometheus -->

<!-- playground provides: kind cluster with cert-manager, the OpenTelemetry Operator 0.160.0 and a trimmed Prometheus (Prometheus Operator and one Prometheus). The OpenTelemetry Collector contrib image 0.162.0 is preloaded, but no Collector is deployed yet. `scout` in `starfleet` and `probe` in `outpost`, with a traffic loop in `shuttle` that makes `probe` log both 200 and 500 responses. No log storage backend: logs are read with the debug exporter and counted into a Prometheus metric. -->

<!-- module section-020/module-02 (Module 2) — stub written by /astrona-course-domain-scaffold, prose written by /astrona-course-domain-build. -->

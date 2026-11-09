---
title: "Run An OpenTelemetry Collector With The Operator"
maturity: published
reviewed: "2026-11-08"
---

# Run An OpenTelemetry Collector With The Operator

Metrics can reveal that requests are slow, but they do not show which step caused the delay. A trace follows a request across services, recording the start time and duration of each instrumented operation as a **span**. The exam expects you to build and troubleshoot the path that carries these spans to a tracing backend.

This path has three components:

- **Instrumented application:** Creates spans that describe the work performed during a request.
- **OpenTelemetry Collector:** Receives, batches, and forwards spans.
- **Tracing backend, such as Jaeger:** Stores traces and makes them available for searching and analysis.

On Kubernetes, the OpenTelemetry Operator manages the Collector through an `OpenTelemetryCollector` custom resource. When traces are missing, determine where the flow stops: span creation, collection and forwarding, or backend ingestion.

## Learning Objectives

After completing this module, you will be able to:

- Check that the OpenTelemetry Operator runs after cert-manager and that its webhook is ready.
- Configure an `OpenTelemetryCollector` with an OTLP receiver, a batch processor, and an exporter that sends traces to Jaeger.
- Choose between Deployment, DaemonSet, and sidecar Collector modes.
- Send a test trace over OTLP and locate it in the Jaeger API and web interface.
- Troubleshoot tracing pipelines using Service ports, Collector logs, and Collector counters.
- Search spans by tag in the Jaeger web interface and API, identify legacy search routes on older servers, and update the corresponding Deployment.
- Export an exact number of service traces as JSON and verify the count using distinct trace IDs.
- Identify services with spans marked `ERROR`, export their `exception` span events as JSON, and resolve the cause described in the exception message.

## Before You Start

### Required Knowledge and Tools

You should be able to:

- Read Kubernetes Services and identify their exposed ports.
- Forward ports using `kubectl port-forward`.
- Inspect container logs using `kubectl logs`.
- Run commands inside containers using `kubectl exec`.

You need these tools on your machine:

- `kubectl`
- `jq`

### Playground Environment

The playground uses a single-node `kind` cluster with:

- Kubernetes **1.35**
- cert-manager **1.21.3**
- OpenTelemetry Operator **0.162.0**, with its webhook ready
- Jaeger **2.22.0**

During this module, you will create and configure OpenTelemetry Collectors with the **contrib 0.162.0** image.

A Prometheus stack is omitted to reduce memory usage.

### Preconfigured Workloads

| Namespace | Workload | Configuration |
| --- | --- | --- |
| `observability` | `jaeger` | A single Jaeger pod with in-memory storage. The `jaeger` Service exposes OTLP on ports `4317` and `4318`, and the web interface and API on port `16686`. |
| `starfleet` | `scout` | A single `podinfo` 6.17.0 pod with tracing enabled. It sends spans over OTLP to `otel-collector.observability:4317`. You will create this Collector Service during the module. |
| `starfleet` | `shuttle` | A client pod that requests `scout` every two seconds and sends a slow request to `/delay/1` every tenth round. |
| `starfleet` | `probe` | A small Python program that sends an HTTP request to the address in its `TARGET_URL` variable every two seconds and reports each request as one span straight to Jaeger. A failed request gives the span the status `ERROR`. |

<!-- astrona:playground -->

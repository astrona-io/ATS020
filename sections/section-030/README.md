---
maturity: published
last_reviewed: "2026-11-08"
---

# Distributed Tracing With OpenTelemetry and Jaeger

Learn to deploy an OpenTelemetry Collector using the OpenTelemetry Operator, send traces to Jaeger, and investigate requests through the Jaeger dashboard. Add tracing to applications using automatic instrumentation without changing their source code.

Building on metrics and logging, this chapter introduces Collector pipelines for receiving, processing, and exporting traces, metrics, and logs. Use distributed tracing to follow requests across services and identify where time is spent.

**Curriculum item covered:** Implementing Monitoring, Alerting, Logging, and Tracing Solutions

## What You Will Master

- Install the OpenTelemetry Operator after cert-manager and verify its webhook is ready
- Configure an OpenTelemetryCollector with an OTLP receiver, batch processor, and Jaeger exporter endpoint
- Choose between Deployment, DaemonSet, and sidecar Collector modes
- Send test traces over OTLP and locate them in the Jaeger UI and API
- Troubleshoot Collector pipelines using logs and configuration
- Search spans by tag using the Jaeger UI and `/api/v3` query API, and recognise legacy search routes
- Use trace findings to update environment variables and scale Deployments
- Export a specified number of service traces to a JSON file and verify the count using distinct trace IDs
- Configure an Instrumentation resource with an exporter endpoint, propagators, and sampler
- Enable automatic instrumentation through Deployment pod-template annotations and restart the pods
- Verify agent injection through init containers and environment variables
- Follow a request across services and identify its slowest span
- Troubleshoot missing instrumentation caused by incorrect annotations, namespace references, or pods that need restarting

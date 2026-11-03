# Summary

An application should send its spans to a Collector, and the Collector should send them on to a backend. This module built that path on Kubernetes with the OpenTelemetry Operator and followed a trace from `scout` to Jaeger.

## What you learned

The OpenTelemetry Operator turns an OpenTelemetryCollector resource into a Deployment, a DaemonSet or an injected sidecar, a ConfigMap with the Collector configuration, and Services. It needs cert-manager, because its admission webhooks need a certificate that the API server trusts. The Operator is ready when its `Certificate` is `READY True`, and a request that only the webhook can reject, run with `--dry-run=server`, proves that the webhook answers.

A Collector is built from receivers, processors and exporters, connected by pipelines. The Collector only starts a part that a pipeline lists. The Operator builds the Service ports from the receivers that pipelines use, and it names the Service `<name>-collector`. OTLP uses port `4317` for gRPC and `4318` for HTTP, and an exporter to a backend without TLS needs `tls.insecure: true`.

A trace is the set of spans of one request. The spans share one trace ID, each span has a parent span ID, and the root span has none. The `traceparent` header carries the trace ID from one service to the next. Jaeger stores the spans, and its API on port `16686` finds them by service name, time range and minimum duration. A test trace from `telemetrygen` separates a fault in the application from a fault in the pipeline.

The `mode` field decides where the Collector runs. A `deployment` is a shared gateway, a `daemonset` is an agent on each node, and a `sidecar` is a container injected into a pod that carries the `sidecar.opentelemetry.io/inject` annotation. The mode of an existing Collector cannot change; delete the resource and create it again.

A Collector in `Running` can still be broken. Read the Service ports, the startup lines in the log, the retry lines of the exporter and the counters `otelcol_receiver_accepted_spans` and `otelcol_exporter_sent_spans`. The proof of a fix is that `scout` appears in Jaeger and both counters rise together. The key facts to remember are these:

- The Operator needs cert-manager first, and its webhook must answer before you create a Collector.
- A part that no pipeline lists does not run.
- Port `4317` is OTLP over gRPC and port `4318` is OTLP over HTTP.
- A Collector mode cannot be changed in place.
- A fix is proved by a trace in Jaeger, not by a `Running` pod.

<!-- astrona:playground:destroy -->

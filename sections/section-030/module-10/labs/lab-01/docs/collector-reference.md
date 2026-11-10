# Collector Reference

This page is a short reference for the OpenTelemetry Collector, a program that receives, processes and exports telemetry. The OpenTelemetry Operator runs it from an OpenTelemetryCollector resource. The page lists where the fields live and how to read the Collector's own status. It does not solve the task.

## Where the configuration lives

The Operator reads `spec.config` of the OpenTelemetryCollector and writes it into the Collector's configuration. When you apply a change, the Operator replaces the Collector pod. The new pod needs about 40 seconds before its log shows the new behaviour.

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: <name>
  namespace: <namespace>
spec:
  mode: deployment
  config:
    receivers: {}    # where data comes in
    processors: {}   # what changes it on the way
    exporters: {}    # where data goes
    service:
      pipelines: {}  # which receivers, processors and exporters work together, per signal
```

## Services the Operator creates

For an OpenTelemetryCollector named `<name>`, the Operator creates these Services in the same namespace:

| Service | Ports |
| --- | --- |
| `<name>-collector` | the ports of the receivers, for example `4317` |
| `<name>-collector-headless` | the same ports, one DNS record per pod |
| `<name>-collector-monitoring` | `8888`, the Collector's own metrics |

## Read the Collector's own status

The Collector reports its own metrics on port `8888` at `/metrics`. Three counters show the path of spans through it:

| Counter name starts with | Goes up when |
| --- | --- |
| `otelcol_receiver_accepted_spans` | a receiver accepts spans from an application |
| `otelcol_exporter_sent_spans` | an exporter delivers spans to its backend |
| `otelcol_exporter_send_failed_spans` | an exporter fails to deliver spans |

The Collector log has one line for every failed export. Read the `error` field of that line: it says what the exporter tried and why it failed.

## Jaeger

Jaeger is a tracing backend that stores traces and shows them in a web UI. On the **Jaeger** tab, choose a service in the **Service** list and select **Find Traces**. A service appears in that list only after Jaeger has stored at least one of its spans.

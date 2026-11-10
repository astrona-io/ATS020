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

## Fields of an OTLP gRPC exporter

OTLP is the OpenTelemetry Protocol, the wire format for telemetry. Port `4317` carries OTLP over gRPC.

| Field | Meaning |
| --- | --- |
| `endpoint` | `host:port` the exporter connects to. Inside the cluster, the host is a Service name: `<service>.<namespace>` |
| `tls.insecure` | `true` sends plain gRPC with no TLS (Transport Layer Security). Default `false`: the exporter starts a TLS handshake |
| `tls.ca_file` | A CA certificate file used to check the server's certificate when TLS is on |
| `timeout` | How long one export request may take |

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

The Collector log names the exporter and the error for every failed export. The `error` field says what went wrong:

| Error text contains | Meaning |
| --- | --- |
| `no children to pick from` | the gRPC client found no address for the host, often a Service name that does not exist |
| `connection refused` | the address exists, but nothing listens on that port |
| `first record does not look like a TLS handshake` | the exporter speaks TLS, but the server answers in plain text |
| `authentication handshake failed: x509` | TLS is on, but the server's certificate is not trusted |

## Jaeger

Jaeger is a tracing backend that stores traces and shows them in a web UI. On the **Jaeger** tab, choose a service in the **Service** list and select **Find Traces**. A service appears in that list only after Jaeger has stored at least one of its spans.

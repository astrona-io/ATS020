# Overview: Run An OpenTelemetry Collector With The Operator (Playground)

This playground gives you a cluster with a trace backend, a workload that
already creates spans, and no Collector. A span is one timed step of a
request, and a trace is all the spans of one request. You install the
OpenTelemetry Operator, create a Collector with it, and follow the traces
into Jaeger. There is no grading.

## What's in the box

The cluster runs Kubernetes 1.35.8. cert-manager 1.21.2 is installed and
ready. The OpenTelemetry Operator is not installed. A Prometheus stack is not
installed either, to save memory.

| Namespace | Contents |
| --- | --- |
| `cert-manager` | cert-manager 1.21.2, which issues the certificate for the Operator's webhook |
| `observability` | Jaeger 2.22.0 in one pod with in-memory storage. The Service `jaeger` has OTLP on `4317` (gRPC) and `4318` (HTTP), and the web interface on `16686` |
| `starfleet` | `scout`, which sends its spans over OTLP to `otel-collector.observability:4317`, and `shuttle`, which sends a request to `scout` every 2 seconds |

The Service `otel-collector` does not exist yet. The Operator creates it when
you create an OpenTelemetryCollector named `otel` in `observability`. Until
then, the `scout` logs show export errors, and Jaeger holds no `scout` traces.

Jaeger keeps traces in memory only. If the `jaeger` pod restarts, the traces
are gone.

## Helpers

Use a second terminal for the port-forward and leave it running:

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

Open `http://127.0.0.1:16686` for the Jaeger web interface. The Jaeger
application programming interface (API) is on the same port. These helpers
use `curl` and `jq` on your machine. The first lists the services that have
sent spans. The second lists the spans of the last 15 minutes for one
service. The date commands are for macOS; on Linux use `date -u -d '-15 min'`
and `date -u -d '+1 min'`.

```sh
list_services() {
  curl -fsS http://127.0.0.1:16686/api/v3/services | jq -c '.services'
}
list_spans() {
  START=$(date -u -v-15M +%Y-%m-%dT%H:%M:%SZ)
  END=$(date -u -v+1M +%Y-%m-%dT%H:%M:%SZ)
  curl -fsS "http://127.0.0.1:16686/api/v3/traces?query.service_name=$1&query.start_time_min=$START&query.start_time_max=$END" |
    jq -c '[.result.resourceSpans[].scopeSpans[].spans[] | {name, traceId}]'
}
```

## Practice tasks

- Install the OpenTelemetry Operator and confirm that its webhook certificate is ready.
- Create an OpenTelemetryCollector named `otel` with an OTLP receiver, a batch processor and an exporter to Jaeger. Find the Service the Operator creates.
- Find a `scout` trace in Jaeger, in the web interface and with the API.
- Send a test trace with `telemetrygen` and find it by its service name.
- Create a second Collector in `daemonset` mode and one in `sidecar` mode. Inject the sidecar into `scout` with an annotation.
- Break the pipeline on purpose (a wrong exporter port, a receiver left out of the pipeline) and read the Collector logs to find each fault.

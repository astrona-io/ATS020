# Overview: Add Tracing Without Code Changes Using Auto-Instrumentation (Playground)

This playground gives you a trace backend, a working Collector and two
services, and only one of the services creates spans. The other service,
`relay`, is a plain Node.js program with no tracing code. You tell the
OpenTelemetry Operator to inject a tracing agent into it, and you follow one
request across both services in Jaeger. There is no grading.

## What's in the box

The cluster runs Kubernetes 1.35.8. cert-manager 1.21.3 and the OpenTelemetry
Operator 0.162.0 are installed and ready. A Prometheus stack is not installed,
to save memory.

| Namespace | Contents |
| --- | --- |
| `cert-manager` | cert-manager 1.21.3, which issues the certificate for the Operator's webhook |
| `opentelemetry-operator-system` | The OpenTelemetry Operator 0.162.0 |
| `observability` | Jaeger 2.22.0 in one pod with in-memory storage, and the Collector `otel` (contrib 0.162.0, `deployment` mode). The Service `otel-collector` takes OTLP on `4317` (gRPC) and `4318` (HTTP) |
| `starfleet` | `scout`, `relay` and `shuttle` |

`scout` is `podinfo` 6.15.0 with its own OpenTelemetry tracing on. It sends its
spans to `otel-collector.observability:4317`. `relay` is `node:22-alpine`
running a small HTTP server from the ConfigMap `relay-app`. Each request to
`relay` makes one request to `scout`. A request to `relay` at `/slow` asks
`scout` for `/delay/1`, so it takes about one second. `shuttle` sends a request
to `relay` every 2 seconds, and a slow one every fifth round.

No Instrumentation resource exists. `relay` has no annotation. Until you add
both, Jaeger holds only the traces of `scout`, and each of them has a single
service.

Jaeger keeps traces in memory only. If the `jaeger` pod restarts, the traces
are gone.

## Helpers

Use a second terminal for the port-forward and leave it running:

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

Open `http://127.0.0.1:16686` for the Jaeger web interface. The Jaeger
application programming interface (API) is on the same port. This helper uses
`curl` and `jq` on your machine. It prints the spans of the latest traces for
one service, and it leaves out the `GET /readyz` spans that the readiness
probe of `scout` creates:

```sh
list_spans() {
  curl -fsS "http://127.0.0.1:16686/api/v3/traces?query.service_name=$1&query.start_time_min=2020-01-01T00:00:00Z&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=${2:-1}" |
    jq -c '.result.resourceSpans[] | (.resource.attributes[] | select(.key=="service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | select(.name != "GET /readyz") | {service: $service, name, traceId, spanId, parentSpanId}'
}
```

## Practice tasks

- Create an Instrumentation named `nodejs` in `starfleet` that exports to the Collector over HTTP on port `4318`. Annotate `relay` so the Operator injects the Node.js agent. Find the init container and the `OTEL_*` variables in the new pod.
- Find a trace in Jaeger that has spans from `relay` and `scout`. Name the slowest span of a `/slow` request.
- Change the `propagators` list to `baggage` only. Restart `relay` and show that its spans and the spans of `scout` fall into separate traces. Change it back.
- Put the annotation on the Deployment instead of the pod template. Show that the new pod has no init container, and that the Operator log has no error.
- Delete the Instrumentation, restart `relay`, and read the Operator log for the error. Create the Instrumentation again and show that a running pod stays as it is until you restart it.
- Use the annotation value `observability/nodejs` with an Instrumentation in the `observability` namespace.

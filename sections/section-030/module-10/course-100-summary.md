# Summary

An application should send its spans to a Collector, and the Collector should send them on to a backend. This module built that path on Kubernetes with the OpenTelemetry Operator and followed a trace from `scout` to Jaeger.

## What you learned

The OpenTelemetry Operator turns an OpenTelemetryCollector resource into a Deployment, a DaemonSet or an injected sidecar, a ConfigMap with the Collector configuration, and Services. It needs cert-manager, because its admission webhooks need a certificate that the API server trusts. The Operator is ready when its `Certificate` is `READY True`, and a request that only the webhook can reject, run with `--dry-run=server`, proves that the webhook answers.

A Collector is built from receivers, processors and exporters, connected by pipelines. The Collector only starts a part that a pipeline lists. The Operator builds the Service ports from the receivers that pipelines use, and it names the Service `<name>-collector`. OTLP uses port `4317` for gRPC and `4318` for HTTP, and an exporter to a backend without TLS needs `tls.insecure: true`.

A trace is the set of spans of one request. The spans share one trace ID, each span has a parent span ID, and the root span has none. The `traceparent` header carries the trace ID from one service to the next. Jaeger stores the spans, and its API on port `16686` finds them by service name, time range and minimum duration. A test trace from `telemetrygen` separates a fault in the application from a fault in the pipeline.

The `mode` field decides where the Collector runs. A `deployment` is a shared gateway, a `daemonset` is an agent on each node, and a `sidecar` is a container injected into a pod that carries the `sidecar.opentelemetry.io/inject` annotation. The mode of an existing Collector cannot change; delete the resource and create it again.

A Collector in `Running` can still be broken. Read the Service ports, the startup lines in the log, the retry lines of the exporter and the counters `otelcol_receiver_accepted_spans` and `otelcol_exporter_sent_spans`. The proof of a fix is that `scout` appears in Jaeger and both counters rise together.

A span can also carry tags, which OpenTelemetry calls attributes, and a tag can lead you to a service you could not name. The web interface of Jaeger 2.22 takes tags in its Attributes field. Its version 3 API takes them as a JSON object in `query.attributes`, together with a required time range, and older guides show a legacy search form that this release no longer serves. The service name is on the resource and not on the span. To save an exact number of traces, limit the search with `query.searchDepth` and write the response to a file. One trace can fill more than one `resourceSpans` entry, so count distinct trace IDs.

Jaeger 1.x and 2.0 through 2.20 also serve the older `/api/services` and
`/api/traces` search routes. Jaeger 2.21.0 removed them. Probe the service
routes before choosing the search form: the older search uses `service`,
JSON `tags` and `limit`, and returns traces in `data`.

A tag tells you which service a request belongs to, and the span status tells you whether a step worked. The status code is `UNSET`, `OK` or `ERROR`, written `0`, `1` and `2` in OTLP JSON. The application sets it, and when it catches an exception it also adds a span event named `exception` with `exception.type`, `exception.message` and `exception.stacktrace`. Jaeger marks such a span with the tag `error=true`. Through the API, a `jq` filter on `status.code` finds the failed spans, and collecting their `exception` events into a JSON array keeps the evidence after Jaeger restarts. The message points at the cause, and the newest traces, read after the new pod runs, prove the fix.

The key facts to remember are these:

- The Operator needs cert-manager first, and its webhook must answer before you create a Collector.
- A part that no pipeline lists does not run.
- Port `4317` is OTLP over gRPC and port `4318` is OTLP over HTTP.
- A Collector mode cannot be changed in place.
- A fix is proved by a trace in Jaeger, not by a `Running` pod.
- A trace search through the API needs a time range, and a `404` means that no trace matched.
- Count traces in an API response by distinct trace IDs, not by `resourceSpans` entries.
- A failed span has the status code `2` (`ERROR`), and the cause is in its `exception` event.

<!-- astrona:playground:destroy -->

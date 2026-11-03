# Summary

A service can be traced without a change to its code. The OpenTelemetry Operator adds a tracing agent to a pod while the pod is created, and the agent sends spans to the Collector. This module instrumented a Node.js service named `relay` and followed one request from `relay` to `scout` in Jaeger.

## What you learned

The Operator does the injection in a mutating admission webhook. The API server calls the webhook for every pod it creates, and the webhook reads the annotation `instrumentation.opentelemetry.io/inject-nodejs`. It finds the Instrumentation, then adds an init container, a shared volume and environment variables to the pod. The init container copies the agent, and the variable `NODE_OPTIONS` makes Node.js load it before the application code. The webhook only sees create requests, so a running pod never changes. A pod must be created again after the Instrumentation and the annotation both exist.

The Instrumentation holds the exporter endpoint, the propagators and the sampler. The Operator turns them into the variables `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_PROPAGATORS` and `OTEL_TRACES_SAMPLER`. The annotation belongs on the pod template, not on the Deployment. The value `"true"` selects the Instrumentation in the namespace of the pod, and the value `<namespace>/<name>` selects one in another namespace.

A trace crosses a service border only when the first service sends a `traceparent` header and the second service reads it. This is context propagation, and the propagator `tracecontext` provides it. With only `baggage` in the list, both services still send spans, but each service starts its own trace. The proof of a joined trace is a span of the second service whose parent is a span of the first. The slowest step of a slow request is the deepest span that holds the time, because every parent lasts at least as long as its children.

An instrumented setup that fails gives few signs. Four checks find the cause in order: the init container in the pod, the place of the annotation, the line `failed to select an OpenTelemetry Instrumentation instance for this pod` in the Operator log, and whether the pod was created after the fix. The key facts to remember are these:

- The webhook changes a pod only at creation.
- The annotation goes on the pod template.
- A missing Instrumentation shows in the Operator log. A misplaced annotation shows nowhere.
- `tracecontext` in the propagators joins the spans of two services into one trace.
- A fix is proved by a trace in Jaeger with a child span in the second service, not by a `Running` pod.

<!-- astrona:playground:destroy -->

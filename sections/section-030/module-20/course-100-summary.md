# Summary

The OpenTelemetry Operator can inject a Node.js tracing agent without changing application source code. Its admission webhook adds an init container, a shared volume, and environment variables when the pod is created. The init container copies the agent, and `NODE_OPTIONS` loads it into the application process.

An Instrumentation resource supplies the exporter endpoint, propagators, and sampler. The injection annotation belongs on the Deployment's pod template so new pods carry it. Resource references select settings in the pod's namespace or another namespace. Changes to those settings require replacement pods before the application uses them.

Context propagation connects operations across service calls. With `tracecontext` enabled, `relay` sends a `traceparent` header and `scout` continues the trace. Baggage carries additional context but does not replace trace identity. A shared trace identifier and the parent link between the services establish that a request was recorded across both.

Span timings help locate a delay when read alongside the request structure. In the slow request, `relay` waits while `scout` runs `delayHandler`. Parent durations include that wait, so the longest span does not by itself identify the cause. Saved trace data preserves the identifiers and timing evidence behind the finding.

Troubleshooting starts with the observed failure: missing pod, missing injection, missing exports, or separate traces. Inspect the pod template, selected Instrumentation, injected settings, and relevant logs. Verify a repair with new spans after the rollout; an old trace or a running pod alone cannot confirm it.

<!-- astrona:playground:destroy -->

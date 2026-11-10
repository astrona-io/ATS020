# Question

Solve this question on: `terminal`

Both `relay` and `scout` send spans to Jaeger, but their requests appear in separate traces. The Node.js agent is already injected into `relay`. An agent-settings change removed trace context propagation.

## Tasks

1. Inspect the Instrumentation `nodejs` in `starfleet` and the running `relay` pod's `OTEL_PROPAGATORS`. Identify why the outgoing request cannot continue the trace in `scout`.
2. Restore `tracecontext` alongside `baggage` on that Instrumentation. Keep its exporter endpoint and sampler unchanged.
3. Restart the `relay` Deployment. Check that the replacement pod uses the restored propagators.
4. Find a new trace containing both services, with a `scout` span whose parent is a `relay` span in the same trace.

## Constraints

- Keep `relay`'s image `node:22-alpine`, command, and application code unchanged.
- Do not modify `scout`, `shuttle`, the Collector, or Jaeger.
- Send spans through the Collector, and keep the `relay` Deployment.

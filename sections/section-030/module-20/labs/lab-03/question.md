# Question

Solve this question on: `terminal`

The team has deployed `relay`, a Node.js service in `starfleet` that calls `scout`. Only `scout` sends spans. Enable tracing for `relay` through the installed OpenTelemetry Operator, without changing application code.

Allow about 10 minutes for the four tasks, plus cluster startup and span export time.

## Tasks

1. Create an Instrumentation named `nodejs` in `starfleet`. Use `http://otel-collector.observability:4318`, the `tracecontext` and `baggage` propagators, and sampler `parentbased_traceidratio` with argument `"1"`.
2. Add the Node.js injection annotation to the `relay` Deployment's pod template. Wait for its replacement pod.
3. Inspect that pod's injected init container and environment variables. Confirm that they contain the agent, Collector endpoint, propagators, and sampler settings you requested.
4. Confirm that Jaeger receives new spans with service name `relay`.

## Constraints

Keep `relay`'s image `node:22-alpine`, command, and application code unchanged. Do not modify `scout`, `shuttle`, the Collector, or Jaeger. Send spans through the Collector, and keep the `relay` Deployment.

## How the answer is checked

Three checks verify the injected settings, unchanged application design, and recent `relay` spans in Jaeger. The span check retries while exported batches arrive. You do not need to save a file or analyze parent identifiers in this lab.

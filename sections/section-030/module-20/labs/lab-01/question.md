# Question

Solve this question on: `terminal`

After a deployment change, `relay` in `starfleet` still serves requests but no longer has an injected Node.js agent. An Instrumentation named `nodejs` exists in `observability`, with working exporter, propagator, and sampler settings. The injection annotation is misplaced and selects the wrong namespace.

Repair injection without changing the application.

## Tasks

1. Compare the injection annotation on the Deployment, its pod template, and the running pod. Locate the existing Instrumentation.
2. Put the annotation on the pod template and select a usable Instrumentation. You may reference `observability/nodejs` or create equivalent settings in `starfleet`.
3. Ensure the Deployment creates a replacement pod. Verify its injected init container, agent environment, and Collector endpoint.
4. Confirm that a new trace links a `scout` span to a `relay` parent span.

## Constraints

- Keep `relay`'s image `node:22-alpine`, command, and application code unchanged.
- Do not modify `scout`, `shuttle`, the Collector, or Jaeger.
- Send spans through the Collector, and keep the `relay` Deployment.

# Breaking and Restoring Context Propagation

Both services can send spans successfully while their requests appear as separate traces. This happens when the caller does not pass trace context to the downstream service. You will remove that setting from `relay`, observe the result, and restore it.

The starting setup needs an injected `relay` pod, an Instrumentation named `nodejs` in `starfleet`, and a working Collector exporting to Jaeger. Keep a Jaeger port-forward available at `http://127.0.0.1:16686`.

## Establish a linked trace

**Context propagation** carries a trace identifier and parent span identifier with an application request. The `tracecontext` propagator uses the World Wide Web Consortium (W3C) Trace Context format, including the `traceparent` HTTP header. The `baggage` propagator carries additional key-value context, which does not supply the trace identifier.

<!-- astrona:playground:renew -->

If needed, start `kubectl -n observability port-forward svc/jaeger 16686:16686` in a second terminal. Define the span helper in your first terminal and confirm that a recent trace links `relay` to `scout`:

```sh
list_spans() {
  curl -fsS "http://127.0.0.1:16686/api/v3/traces?query.service_name=$1&query.start_time_min=2020-01-01T00:00:00Z&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=${2:-1}" |
    jq -c '.result.resourceSpans[] | (.resource.attributes[] | select(.key=="service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | select(.name != "GET /readyz") | {service: $service, name, traceId, spanId, parentSpanId}'
}
list_spans relay 1
```

Look for a `scout` span whose `parentSpanId` matches a `relay` span's `spanId`, with both sharing one `traceId`. If batches are still arriving, wait and inspect several traces with `list_spans relay 5`.

## Remove trace context from new pods

The Instrumentation resource supplies the injected agent's exporter, propagator, and sampler settings. Keep the exporter and sampler unchanged, but leave only `baggage` in the propagator list. Save this as `instrumentation-nodejs-baggage.yaml`:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: nodejs
  namespace: starfleet
spec:
  exporter:
    endpoint: http://otel-collector.observability:4318
  propagators:
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1"
```

Apply it:

```sh
kubectl apply -f instrumentation-nodejs-baggage.yaml
```

Then inspect the running pod's setting:

```sh
kubectl -n starfleet get pod -l app=relay -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="OTEL_PROPAGATORS")].value}{"\n"}'
```

The apply and inspection together show:

```text
instrumentation.opentelemetry.io/nodejs configured
tracecontext,baggage
```

The resource changed, but the pod still has `tracecontext,baggage`. The Operator wrote that environment variable when it created the pod. Restart the Deployment and wait until only the replacement pod is listed, then inspect it:

```sh
kubectl -n starfleet rollout restart deployment/relay
kubectl -n starfleet rollout status deployment/relay
kubectl -n starfleet get pod -l app=relay -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="OTEL_PROPAGATORS")].value}{"\n"}'
```

The new pod reports `baggage`:

```text
deployment.apps/relay restarted
Waiting for deployment "relay" rollout to finish: 1 old replicas are pending termination...
deployment "relay" successfully rolled out
baggage
```

This change affects outgoing request headers. The exporter still sends spans to the Collector at the same endpoint.

## Compare traces after the rollout

Allow at least 20 seconds for new requests and span export. Search both services:

```sh
list_spans relay 1
list_spans scout 5 | head -2
```

New traces now resemble these:

```text
{"service":"relay","name":"GET","traceId":"610828339b90aa4b72148b11b179eeb1","spanId":"e9f03855758c5c5a","parentSpanId":"a7ce6cc4df43a211"}
{"service":"relay","name":"GET","traceId":"610828339b90aa4b72148b11b179eeb1","spanId":"a7ce6cc4df43a211","parentSpanId":null}
{"service":"scout","name":"GET /","traceId":"0d38bfeb69da128d2553c7bd112f4f2e","spanId":"284203252f92f8ab","parentSpanId":null}
{"service":"scout","name":"infoHandler","traceId":"0d38bfeb69da128d2553c7bd112f4f2e","spanId":"63f2c059c580fbec","parentSpanId":"284203252f92f8ab"}
```

`relay` records its incoming and outgoing requests under one trace identifier. `scout` starts a separate trace whose request span has no parent. Without the caller's trace context, `scout` cannot continue the caller's trace.

Check timestamps in Jaeger to distinguish these new traces from older linked traces. Exported batches from the old pod can arrive after a rollout. Also, independently querying each service does not pair requests by itself; the changed propagator setting and the repeated new root spans explain the observed separation here.

## Restore context propagation

Restore both propagators while retaining the Collector endpoint and parent-based sampler. Save this as `instrumentation-nodejs.yaml`:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: nodejs
  namespace: starfleet
spec:
  exporter:
    endpoint: http://otel-collector.observability:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1"
```

Apply it:

```sh
kubectl apply -f instrumentation-nodejs.yaml
```

Create a replacement pod and wait for its rollout:

```sh
kubectl -n starfleet rollout restart deployment/relay
kubectl -n starfleet rollout status deployment/relay
```

Read `OTEL_PROPAGATORS` again after the old pod disappears. It should contain `tracecontext,baggage`. Allow new spans to arrive, then use `list_spans relay 5` and the Jaeger timeline to confirm a new trace linking both services. On slower environments, the Node.js agent can take a few minutes to export its first spans.

The failed and repaired states use the same Collector path. What changed was the context sent with application requests, which determines whether the downstream spans continue the caller's trace.

## Common pitfalls

> [!WARNING]
> - **Expecting a resource edit to change a running process.** Replace the pod to receive the new injected environment.
> - **Using service names as proof of propagation.** Match trace and parent identifiers within one trace.
> - **Reading spans from before the rollout.** Check timestamps and allow old batches to finish arriving.
> - **Treating baggage as trace context.** Keep `tracecontext` enabled for the request headers used by these services.

## Your mission: Restore Trace Context Propagation

You can now distinguish span export from context propagation. Inspect an injected agent, restore its propagators, replace the pod, and verify a new linked trace.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-030-02
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-20/labs/lab-04
```

Grade the completed tasks:

```sh
astrona submit -c sections/section-030/module-20/labs/lab-04
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-030-02-04
astrona start ats-020-playground-030-02
```

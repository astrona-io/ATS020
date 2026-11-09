# Solution Guide: Repair Missing Agent Injection

## Locate the annotation and settings

The Deployment has an annotation, but the Operator reads the resulting pod. Compare the two locations and locate the Instrumentation:

```sh
kubectl -n starfleet get deployment relay -o json | jq '{deployment: .metadata.annotations["instrumentation.opentelemetry.io/inject-nodejs"], pod_template: .spec.template.metadata.annotations["instrumentation.opentelemetry.io/inject-nodejs"]}'
kubectl get instrumentation -A
```

The annotation is on Deployment metadata, and the template has none. The Instrumentation is in `observability`. A value of `"true"` would select from the pod's namespace, `starfleet`, where no Instrumentation exists.

## Correct the pod template

Select the existing settings explicitly. Save this as `relay-injection-fix.yaml`:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-nodejs: null
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-nodejs: "observability/nodejs"
```

Apply the patch:

```sh
kubectl -n starfleet patch deployment relay --patch-file relay-injection-fix.yaml
```

The patch removes the misplaced annotation and requests the named Instrumentation in `observability`. Its exporter, propagators, and sampler are already correct.

## Inspect the replacement pod

The template change creates a new pod. Wait for it, then inspect injection:

```sh
kubectl -n starfleet rollout status deployment/relay
kubectl -n starfleet get pods -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
kubectl -n starfleet get pods -l app=relay -o json | jq '.items[] | select(.metadata.deletionTimestamp == null) | .spec.containers[0].env[] | select(.name | test("NODE_OPTIONS|OTEL_EXPORTER_OTLP_ENDPOINT|OTEL_PROPAGATORS"))'
```

The new pod must have `opentelemetry-auto-instrumentation-nodejs`. Its environment loads the agent, exports to the Collector, and includes `tracecontext,baggage`.

## Verify a new linked trace

Start a Jaeger port-forward in another terminal:

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

Allow the new agent to export, then inspect several traces:

```sh
curl -fsS "http://127.0.0.1:16686/api/v3/traces?query.service_name=relay&query.start_time_min=2020-01-01T00:00:00Z&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=5" |
  jq -c '.result.resourceSpans[] | (.resource.attributes[] | select(.key=="service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | {service: $service, name, traceId, spanId, parentSpanId}'
```

Match a `scout` span's `parentSpanId` to a `relay` span's `spanId` within the same `traceId`. The first batches can take a few minutes. This verifies that the injected agent records and propagates the request.

Submit after checking the result:

```sh
astrona submit -c sections/section-030/module-20/labs/lab-01
```

Creating equivalent settings in `starfleet` and selecting them is also accepted. Changing application code or the exporter destination does not repair the injection request.

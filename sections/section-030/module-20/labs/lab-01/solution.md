# Solution

The `relay` pod has no agent, and the setup has three faults. Each fault alone keeps `relay` out of the trace. This walkthrough finds them one by one and fixes them together.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-030/module-20/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Find the faults

Start with the pod. The Operator adds an init container named `opentelemetry-auto-instrumentation-nodejs` to every pod it instruments. List the init containers of `relay`:

```sh
kubectl -n starfleet get pods -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
```

```text
NAME                     INIT
relay-54b5786f9b-49w9f   <none>
```

The pod has no init container, so the webhook of the Operator did not change it. Next, find where the annotation `instrumentation.opentelemetry.io/inject-nodejs` is. The webhook reads it from the pod, and the pod gets its annotations from the pod template:

```sh
kubectl -n starfleet get deployment relay -o json | jq -c '{deployment: .metadata.annotations["instrumentation.opentelemetry.io/inject-nodejs"], pod_template: .spec.template.metadata.annotations["instrumentation.opentelemetry.io/inject-nodejs"]}'
```

```text
{"deployment":"true","pod_template":null}
```

This is the first fault. The annotation is on the Deployment object, and the pod template has none. The Operator log shows no error for it, because the webhook never sees the annotation. Now look for the Instrumentation:

```sh
kubectl get instrumentation -A
kubectl -n observability get instrumentation nodejs -o jsonpath='{.spec.propagators}{"\n"}'
```

```text
NAMESPACE       NAME     AGE   ENDPOINT                                   SAMPLER                    SAMPLER ARG
observability   nodejs   6m    http://otel-collector.observability:4318   parentbased_traceidratio   1
["baggage"]
```

This shows the second and third fault. The only Instrumentation is in `observability`, but the annotation value `"true"` means the Instrumentation in the namespace of the pod, which is `starfleet`. Its `propagators` list has `baggage` and no `tracecontext`, so even an instrumented `relay` would send no `traceparent` header, and `scout` would start a new trace.

## Fix the Instrumentation

Create the Instrumentation in `starfleet`, with `tracecontext` in the propagators. Save this as `instrumentation-nodejs.yaml`:

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

```text
instrumentation.opentelemetry.io/nodejs created
```

## Move the annotation to the pod template

Save this as `relay-fix.yaml`. It removes the annotation from the Deployment and sets it on the pod template:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-nodejs: null
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-nodejs: "true"
```

Apply the patch. The change to the pod template makes the Deployment create a new pod, and the webhook injects the agent while it creates it:

```sh
kubectl -n starfleet patch deployment relay --patch-file relay-fix.yaml
kubectl -n starfleet rollout status deployment/relay
```

```text
deployment.apps/relay patched
Waiting for deployment "relay" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "relay" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "relay" rollout to finish: 1 old replicas are pending termination...
deployment "relay" successfully rolled out
```

## Prove the fix

First, show the init container and the propagators of the new pod. Your pod name differs:

```sh
kubectl -n starfleet get pod -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
kubectl -n starfleet get pod -l app=relay -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="OTEL_PROPAGATORS")].value}{"\n"}'
```

```text
NAME                     INIT
relay-56747969d8-mjzxx   opentelemetry-auto-instrumentation-nodejs
tracecontext,baggage
```

Second, wait about a minute, because the agent and the Collector batch spans. Then ask Jaeger for its services. In another terminal, run `kubectl -n observability port-forward svc/jaeger 16686:16686` first:

```sh
curl -fsS http://127.0.0.1:16686/api/v3/services | jq -c .services
```

```text
["scout","jaeger","relay"]
```

Third, check the link between the two services. This command lists the spans of the newest trace of `relay`. The span of `scout` must have the client span of `relay` as its parent:

```sh
curl -fsS "http://127.0.0.1:16686/api/v3/traces?query.service_name=relay&query.start_time_min=2020-01-01T00:00:00Z&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=1" |
  jq -c '.result.resourceSpans[] | (.resource.attributes[] | select(.key=="service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | select(.name != "GET /readyz") | {service: $service, name, traceId, spanId, parentSpanId}'
```

Your IDs differ. All spans share one `traceId`, and `GET /` of `scout` has the `spanId` of the client span of `relay` in its `parentSpanId`.

## Another fix the grader accepts

The annotation value can name the Instrumentation with `<namespace>/<name>`. With the value `observability/nodejs`, the Operator uses the Instrumentation in `observability`. That Instrumentation still needs `tracecontext` in its propagators, and the pod must be created again.

## Wrong fixes the grader rejects

- Adding code to the script in the ConfigMap `relay-app` that reads and sets a `traceparent` header. The second check fails, because the script must stay free of tracing code.
- Adding the OpenTelemetry Node.js packages to `relay`, or changing its image. The second check fails.
- Instrumenting `scout` again, or changing its endpoint. The second check fails.
- Pointing the exporter endpoint of `relay` straight at Jaeger. The first check fails, because the agent must send to the Collector.
- Replacing the exporter of the Collector with a `debug` exporter. The second check fails, and no trace reaches Jaeger.
- Deleting the Deployment `relay` and creating a new one with another design. The second check fails.
- Fixing the resources but not creating a new pod. The first check fails, because the running pod has no init container.

When the watch terminal shows every check passing, press Ctrl-C to stop the watch, then submit once:

```sh
astrona submit -c sections/section-030/module-20/labs/lab-01
```

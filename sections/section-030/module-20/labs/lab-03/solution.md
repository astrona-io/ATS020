# Solution Guide: Enable Node.js Agent Injection

## Create the agent settings

Save this as `instrumentation-nodejs.yaml`:

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

The Instrumentation supplies the Collector endpoint, propagators, and sampler. Creating it does not change the existing pod.

## Request injection

Save this as `relay-injection.yaml`:

```yaml
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-nodejs: "nodejs"
```

Patch the Deployment and wait for the replacement pod:

```sh
kubectl -n starfleet patch deployment relay --patch-file relay-injection.yaml
kubectl -n starfleet rollout status deployment/relay
```

The named Instrumentation is in the pod's namespace. The Operator reads the template annotation when Kubernetes creates the pod and injects the Node.js agent.

## Inspect the injected settings

Inspect the new pod, excluding any old pod that is still terminating:

```sh
kubectl -n starfleet get pods -l app=relay -o json | jq '.items[] | select(.metadata.deletionTimestamp == null) | {init: .spec.initContainers[].name, env: [.spec.containers[0].env[] | select(.name | test("NODE_OPTIONS|OTEL_"))]}'
```

The init container must be `opentelemetry-auto-instrumentation-nodejs`. `NODE_OPTIONS` loads the agent. The endpoint must be `http://otel-collector.observability:4318`, propagators `tracecontext,baggage`, sampler `parentbased_traceidratio`, and sampler argument `1`.

## Confirm span export

Start a Jaeger port-forward in another terminal:

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

Query for spans from `relay`:

```sh
curl -fsS "http://127.0.0.1:16686/api/v3/traces?query.service_name=relay&query.start_time_min=2020-01-01T00:00:00Z&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=5" |
  jq -c '.result.resourceSpans[] | (.resource.attributes[] | select(.key=="service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | select($service=="relay") | {service: $service, name, traceId, spanId}'
```

Allow a few minutes for the agent's first export if the result is empty. Spans named `GET` with service name `relay` prove that the injected agent is recording requests and delivering them through the Collector.

Submit after verifying the spans:

```sh
astrona submit -c sections/section-030/module-20/labs/lab-03
```

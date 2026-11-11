# Solution

Work in order. Telemetry arrives late, so wait about a minute after a fix before you look in Jaeger.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-030/capstone/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Create the Collector

Save this as `opentelemetrycollector-otel.yaml`:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel
  namespace: observability
spec:
  mode: deployment
  image: otel/opentelemetry-collector-contrib:0.165.0
  config:
    receivers:
      otlp/grpc:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
      otlp/http:
        protocols:
          http:
            endpoint: 0.0.0.0:4318
    processors:
      batch: {}
    exporters:
      otlp_grpc/jaeger:
        endpoint: jaeger.observability:4317
        tls:
          insecure: true
    service:
      pipelines:
        traces:
          receivers: [otlp/grpc, otlp/http]
          processors: [batch]
          exporters: [otlp_grpc/jaeger]
```

Apply it and check that the Service has both ports:

```sh
kubectl apply -f opentelemetrycollector-otel.yaml
kubectl -n observability get service otel-collector
```

The Operator builds the Service ports from the receivers that a pipeline uses, so both receivers must be in the `traces` pipeline.

## Step 2: Fix the endpoint of scout

`scout` sends to port `4318`, which is OTLP over HTTP. `scout` uses gRPC, so it needs port `4317`:

```sh
kubectl -n starfleet set env deployment/scout OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability:4317
kubectl -n starfleet rollout status deployment/scout
```

Before the fix, the `scout` log shows an export error. Read it with `kubectl -n starfleet logs deploy/scout --tail=2`.

## Step 3: Instrument relay

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

Apply it, then add the annotation to the pod template of `relay`. The annotation must be on the pod template, not on the Deployment, and the Operator injects the agent only into pods that are created after the annotation exists. The patch creates a new pod:

```sh
kubectl apply -f instrumentation-nodejs.yaml
kubectl -n starfleet patch deployment relay --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"true"}}}}}'
kubectl -n starfleet rollout status deployment/relay
```

The `tracecontext` propagator sends the trace ID in the `traceparent` header, so the span of `scout` becomes a child of the span of `relay`.

## Step 4: Find the slow call

Open Jaeger:

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

Open `http://localhost:16686`, choose the service `relay` and sort the traces by duration. Open the longest trace. The span of `relay` is about one second long, and its child span from `scout` is almost as long. Open the trace and click through the spans. Two spans of `scout` last about one second: the server span for the request (its name starts with `GET /delay`) and, below it, a step that has no child span of its own. The step with no child holds the time. Do not type a span name from memory: read it in the Jaeger interface, or list the names of the slow spans of `scout` with the API:

```sh
kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces?query.service_name=relay&query.duration_min=500ms&query.start_time_min=$(date -u -v-10M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)&query.start_time_max=2100-01-01T00:00:00Z" | grep -o '"name":"[^"]*delay[^"]*"' | sort -u
```

The grader accepts either span name, as long as it is spelled exactly as Jaeger shows it. Record it, with the span name as the value of `operation`:

```sh
kubectl -n starfleet create configmap slow-call --from-literal=service=scout --from-literal=operation="<span name from Jaeger>"
```

The watch terminal shows all four checks passing. Press Ctrl-C to stop the watch, then submit once:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

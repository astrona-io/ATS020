# Solution Guide: Restore Trace Context Propagation

## Compare resource and pod settings

The agent already exports spans. Inspect its propagation settings in the resource and the running pod:

```sh
kubectl -n starfleet get instrumentation nodejs -o jsonpath='{.spec.propagators}{"\n"}'
kubectl -n starfleet get pods -l app=relay -o json | jq -r '.items[] | select(.metadata.deletionTimestamp == null) | .spec.containers[0].env[] | select(.name=="OTEL_PROPAGATORS") | .value'
```

Both show only `baggage`. Baggage carries additional context, but it does not carry the trace identity needed by `scout` to continue the request's trace.

## Restore trace context

Save this as `propagators-fix.yaml`:

```yaml
spec:
  propagators:
    - tracecontext
    - baggage
```

Patch the existing Instrumentation:

```sh
kubectl -n starfleet patch instrumentation nodejs --type=merge --patch-file propagators-fix.yaml
```

The patch changes only the propagators. The Collector endpoint and sampler remain configured as before.

## Replace the pod

The running process still uses its original environment. Restart the Deployment and inspect the replacement:

```sh
kubectl -n starfleet rollout restart deployment/relay
kubectl -n starfleet rollout status deployment/relay
kubectl -n starfleet get pods -l app=relay -o json | jq -r '.items[] | select(.metadata.deletionTimestamp == null) | .spec.containers[0].env[] | select(.name=="OTEL_PROPAGATORS") | .value'
```

The replacement must report `tracecontext,baggage`. Editing the resource without replacing the pod leaves the old propagation behavior in place.

## Confirm a new parent link

Start a Jaeger port-forward in another terminal:

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

Set a search boundary after the rollout. Wait for new requests to be exported, then query:

```sh
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

```sh
curl -fsS "http://127.0.0.1:16686/api/v3/traces?query.service_name=relay&query.start_time_min=$since&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=10" |
  jq -c '.result.resourceSpans[] | (.resource.attributes[] | select(.key=="service.name") | .value.stringValue) as $service | .scopeSpans[].spans[] | {service: $service, name, traceId, spanId, parentSpanId}'
```

Repeat the query while batches arrive. A `scout` request span must name a `relay` span as its parent, and both must share a trace identifier. Older, disconnected traces remain in storage; the time boundary excludes them.

Submit the repair:

```sh
astrona submit -c sections/section-030/module-20/labs/lab-04
```

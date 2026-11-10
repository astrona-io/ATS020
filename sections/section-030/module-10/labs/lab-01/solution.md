# Solution

The pod of the Collector is `Running`, but its exporter cannot reach Jaeger. The exporter has two faults, one behind the other. The first fault hides the second.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-030/module-10/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Find the first fault

In the browser workspace, you can keep the Collector log open on the **Logs** tab with `kubectl -n observability logs deploy/otel-collector -f` and run the other commands in the first terminal. The commands below read only the last lines, so they work in any terminal.

Read the log of the Collector for the exporter errors:

```sh
kubectl -n observability logs deploy/otel-collector --tail=3 | grep -o '"error": "[^}]*'
```

```text
"error": "rpc error: code = Unavailable desc = no children to pick from", "interval": "36.059981238s"
"error": "rpc error: code = Unavailable desc = no children to pick from", "interval": "27.939202642s"
```

The exporter has no address to connect to. Show the exporter endpoint and the Services in `observability`:

```sh
kubectl -n observability get opentelemetrycollector otel -o jsonpath='{.spec.config.exporters}'
kubectl -n observability get service
```

The exporter points at `jaeger-collector.observability:4317`. No Service has that name. The Jaeger Service is named `jaeger`.

## Fix the host

Save this as `opentelemetrycollector-otel.yaml`. It changes the host to `jaeger.observability`:

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
    processors:
      batch: {}
    exporters:
      otlp_grpc:
        endpoint: jaeger.observability:4317
    service:
      pipelines:
        traces:
          receivers: [otlp/grpc]
          processors: [batch]
          exporters: [otlp_grpc]
```

Apply it:

```sh
kubectl apply -f opentelemetrycollector-otel.yaml
```

Wait about 40 seconds for the Operator to replace the pod, then read the log again:

```sh
kubectl -n observability logs deploy/otel-collector --tail=3 | grep -o '"error": "[^}]*'
```

```text
"error": "rpc error: code = Unavailable desc = connection error: desc = \"transport: authentication handshake failed: tls: first record does not look like a TLS handshake\"", "interval": "17.86397711s"
"error": "rpc error: code = Unavailable desc = connection error: desc = \"transport: authentication handshake failed: tls: first record does not look like a TLS handshake\"", "interval": "33.930809312s"
```

## Fix the TLS setting

The host is right now, and the exporter reaches Jaeger. The error is different. The exporter starts a TLS (Transport Layer Security) handshake, but the OTLP port of Jaeger speaks plain gRPC. The exporter needs `tls.insecure: true`, which switches TLS off for this connection.

In `opentelemetrycollector-otel.yaml`, add these two lines under `endpoint: jaeger.observability:4317`, with the same indentation as `endpoint`:

```yaml
        tls:
          insecure: true
```

Apply the file again and wait about 40 seconds:

```sh
kubectl apply -f opentelemetrycollector-otel.yaml
```

## Prove the fix

First, read the Collector counters from `shuttle`. Both counters must be above `0` and rise together. Your numbers differ:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s otel-collector-monitoring.observability:8888/metrics | grep -E "^otelcol_(receiver_accepted_spans|exporter_sent_spans)"
```

Second, ask Jaeger for its services:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s jaeger.observability:16686/api/v3/services | grep -o '"scout"'
```

```text
"scout"
```

In the browser workspace, the same proof is on two tabs. The **Collector metrics** tab shows both counters; reload it to see them rise. On the **Jaeger** tab, choose `scout` in the **Service** list and select **Find Traces** to see its recent traces.

## Wrong fixes the grader rejects

Every check first makes sure the fix stays inside the Collector. A fix that goes around it fails every check:

- Changing `OTEL_EXPORTER_OTLP_ENDPOINT` on `scout` to `jaeger.observability:4317`. Spans arrive in Jaeger, but the Collector is bypassed.
- Deleting the Collector, or changing its mode.
- Replacing the exporter with a `debug` exporter. The log shows spans, but nothing reaches Jaeger.

After you fix only the host, the exporter check passes and the two other checks still fail, because the exporter cannot send yet.

When the watch terminal shows every check passing, press Ctrl-C to stop the watch, then submit once:

```sh
astrona submit -c sections/section-030/module-10/labs/lab-01
```

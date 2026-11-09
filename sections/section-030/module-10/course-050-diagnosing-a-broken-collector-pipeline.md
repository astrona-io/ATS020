# Diagnosing a Broken Collector Pipeline

The `scout` pod can keep serving requests while its traces fail to reach Jaeger. A Collector pod can also remain `Running` with a broken export destination. Kubernetes readiness and trace delivery answer different questions.

You will introduce two configuration faults, then follow the errors from the application to the receiver and exporter. A **receiver** accepts spans, an **exporter** sends them onward, and a **pipeline** connects them through any processors.

## Introduce two configuration faults

The `OpenTelemetryCollector` resource below replaces the configuration of `otel`. It defines separate OpenTelemetry Protocol (OTLP) receivers for gRPC, a remote procedure call transport, and Hypertext Transfer Protocol (HTTP). Only the HTTP receiver appears in the trace pipeline, and the Jaeger exporter points to port `4316`.

<!-- astrona:playground:renew -->

Save this as `opentelemetrycollector-otel-broken.yaml`:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel
  namespace: observability
spec:
  mode: deployment
  image: otel/opentelemetry-collector-contrib:0.162.0
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
        endpoint: jaeger.observability:4316
        tls:
          insecure: true
    service:
      pipelines:
        traces:
          receivers: [otlp/http]
          processors: [batch]
          exporters: [otlp_grpc/jaeger]
```

Apply it:

```sh
kubectl apply -f opentelemetrycollector-otel-broken.yaml
```

Allow about 40 seconds for the Operator to create the replacement pod. Its process can start because the configuration is valid, even though the selected receiver and export address do not match the intended connections.

## Find why the application cannot connect

`scout` exports over gRPC to port `4317`. Read its latest export error:

```sh
kubectl -n starfleet logs deploy/scout --tail=1
```

The log can show a connection timeout like this:

```text
{"level":"info","ts":"2026-11-02T19:12:14.080Z","caller":"errorhandler/errorhandler.go:36","msg":"exporter export timeout: rpc error: code = Unavailable desc = connection error: desc = \"transport: Error while dialing: dial tcp 10.96.220.64:4317: i/o timeout\""}
```

The destination is the Collector Service's cluster address on port `4317`. Check which ports that Service exposes:

```sh
kubectl -n observability get service otel-collector
```

Only the HTTP port appears:

```text
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
otel-collector   ClusterIP   10.96.220.64   <none>        4318/TCP   12m
```

The Operator derives Service ports from receivers used by the pipelines. The resource defines `otlp/grpc`, but its `traces` pipeline lists only `otlp/http`. Check the Collector's startup messages to confirm which receiver started:

```sh
kubectl -n observability logs deploy/otel-collector | awk -F'\t' '/Starting|Everything/{print $2, $3, $4}'
```

The filtered log contains an HTTP server startup and no gRPC server startup:

```text
info service@v0.162.0/service.go:233 Starting otelcol-contrib...
info extensions/extensions.go:43 Starting extensions...
info otlpreceiver@v0.162.0/otlp.go:175 Starting HTTP server
info service@v0.162.0/service.go:256 Everything is ready. Begin running and processing data.
```

Edit the pipeline in `opentelemetrycollector-otel-broken.yaml` so that its receiver list is `receivers: [otlp/grpc, otlp/http]`. Apply the same file again with `kubectl apply -f opentelemetrycollector-otel-broken.yaml` and allow about 40 seconds for the replacement pod. Check the Service again: it should now expose both ports.

## Find why the exporter cannot deliver

With the gRPC receiver active, spans can enter the Collector. The exporter now attempts to deliver them and exposes the second fault. Search for the first connection timeout in the Collector log:

```sh
kubectl -n observability logs deploy/otel-collector | grep -m1 -o 'dial tcp [0-9.:]*: i/o timeout'
```

The error names the destination port:

```text
dial tcp 10.96.10.202:4316: i/o timeout
```

Compare that address with Jaeger's Service:

```sh
kubectl -n observability get service jaeger
```

Jaeger exposes these ports:

```text
NAME     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                       AGE
jaeger   ClusterIP   10.96.10.202   <none>        4317/TCP,4318/TCP,16686/TCP   5m51s
```

The exporter uses `4316`, but Jaeger's OTLP/gRPC receiver listens on `4317`. Change the endpoint in the file to `jaeger.observability:4317`, apply it again, and allow the new Collector pod to start.

Read the Collector's accepted-span and sent-span counters, then check the Jaeger application programming interface (API) for `scout`:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s otel-collector-monitoring.observability:8888/metrics | grep -E "^otelcol_(receiver_accepted_spans|exporter_sent_spans)"
kubectl exec -n starfleet deploy/shuttle -- curl -s jaeger.observability:16686/api/v3/services | grep -o '"scout"'
```

A working configuration produces output like this:

```text
otelcol_exporter_sent_spans{exporter="otlp_grpc/jaeger",server_address="jaeger.observability",server_port="4317"} 55
otelcol_receiver_accepted_spans{receiver="otlp/grpc",transport="grpc"} 55
"scout"
```

Repeat the counter query after a few seconds. Both counters should rise as requests continue. Batching can make them differ briefly, and a Collector restart resets them. The service list confirms that Jaeger knows `scout`; search for a trace created after the repair to confirm current delivery.

## Use each symptom to choose the next check

The first fault prevented spans from reaching the Collector. Repairing it exposed the export failure. A third common fault is a misspelled component name in a pipeline, which can stop the new Collector process before it starts receiving data.

| Symptom | Next check | Likely cause in this exercise |
| --- | --- | --- |
| `scout` times out connecting to port `4317` | Collector Service ports and receiver startup messages | The gRPC receiver is not listed in the pipeline |
| The Collector retries exports to port `4316` | Exporter endpoint and Jaeger Service ports | The exporter uses the wrong port |
| A new Collector pod exits with an invalid-configuration error | Logs from that specific pod | The pipeline refers to an undefined component |

A failed rollout can leave an older pod serving traffic. Inspect the new pod's logs when a change fails, and confirm that the intended configuration is running. Service ports, startup logs, and exporter counters narrow down the fault; a recent trace in Jaeger confirms the repaired path.

## Common pitfalls

> [!WARNING]
> - **Trusting `Running` alone.** Check receiver activity, successful exports, and recent stored traces.
> - **Stopping after the first fix.** A receiver failure can hide an exporter failure. Repeat the checks after each repair.
> - **Reading an old pod's logs.** Select the failing pod explicitly when a rollout leaves several pods running.
> - **Sending `scout` directly to Jaeger.** That bypasses the Collector whose pipeline you need to repair.

## Your mission: Fix a Broken Collector Pipeline

You can now distinguish a receiver failure from an export failure. The mission gives you a running Collector and missing `scout` traces; repair the pipeline and verify that new spans reach Jaeger through it.

Pause the playground, then start the lab:

```sh
astrona stop ats-020-playground-030-01
```

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-10/labs/lab-01
```

When you have repaired the pipeline, grade your work:

```sh
astrona submit -c sections/section-030/module-10/labs/lab-01
```

Remove the lab and restart the playground when you finish:

```sh
astrona destroy ats-020-lab-030-01
astrona start ats-020-playground-030-01
```

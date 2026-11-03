# Diagnosing A Broken Collector Pipeline

A Collector that is `Running` is not a Collector that works. The pod can be healthy while spans never reach the backend, because the fault is in the configuration the Collector reads, not in Kubernetes. This part breaks the pipeline in two ways and follows the symptoms back to their causes, using the Service, the Collector log and the Collector's own metrics.

## Break the pipeline

Save this as `opentelemetrycollector-otel-broken.yaml`. It has the same name as the working Collector, so applying it replaces the configuration. It has two faults. One is easy to see in the YAML once you know to look. The other only shows up in the logs:

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

<!-- astrona:playground:renew -->

```sh
kubectl apply -f opentelemetrycollector-otel-broken.yaml
```

## Symptom one: the application cannot connect

Wait about 40 seconds for the new pod. The Collector pod is `1/1 Running`, and the Operator shows no error. The first sign of trouble is in the application. `scout` writes an error each time it fails to send spans:

```sh
kubectl -n starfleet logs deploy/scout --tail=1
```

```text
{"level":"info","ts":"2026-11-02T19:12:14.080Z","caller":"errorhandler/errorhandler.go:36","msg":"exporter export timeout: rpc error: code = Unavailable desc = connection error: desc = \"transport: Error while dialing: dial tcp 10.96.220.64:4317: i/o timeout\""}
```

The address `10.96.220.64` is the cluster IP of a Service, and port `4317` is where `scout` sends. The connection times out. Look at the Service that the Operator built:

```sh
kubectl -n observability get service otel-collector
```

```text
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
otel-collector   ClusterIP   10.96.220.64   <none>        4318/TCP   12m
```

The Service has only port `4318`. The Operator builds the Service ports from the receivers that the pipelines use, so no pipeline uses a receiver on `4317`. The Collector log confirms it. Only one server started:

```sh
kubectl -n observability logs deploy/otel-collector | awk -F'\t' '/Starting|Everything/{print $2, $3, $4}'
```

```text
info service@v0.162.0/service.go:233 Starting otelcol-contrib...
info extensions/extensions.go:43 Starting extensions...
info otlpreceiver@v0.162.0/otlp.go:175 Starting HTTP server
info service@v0.162.0/service.go:256 Everything is ready. Begin running and processing data.
```

There is no `Starting GRPC server` line. The receiver `otlp/grpc` is defined, but the `traces` pipeline lists only `otlp/http`. An unused receiver never starts. In `opentelemetrycollector-otel-broken.yaml`, change the pipeline line to `receivers: [otlp/grpc, otlp/http]` and apply the file again. Wait about 40 seconds.

## Symptom two: the exporter cannot deliver

The Service now has both ports, and `scout` can connect. Spans enter the Collector, but they do not leave. Search the Collector log for failed exports. The command prints the first connection error it finds:

```sh
kubectl -n observability logs deploy/otel-collector | grep -m1 -o 'dial tcp [0-9.:]*: i/o timeout'
```

```text
dial tcp 10.96.10.202:4316: i/o timeout
```

The Collector tries to reach `10.96.10.202` on port `4316`. Compare it with the Jaeger Service:

```sh
kubectl -n observability get service jaeger
```

```text
NAME     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                       AGE
jaeger   ClusterIP   10.96.10.202   <none>        4317/TCP,4318/TCP,16686/TCP   5m51s
```

The exporter points at a port that does not exist. In the file, change `jaeger.observability:4316` to `jaeger.observability:4317` and apply the file again. Wait about 40 seconds, then prove the fix with two checks from `shuttle`. First, the Collector's counters must be equal and rising, which shows that spans enter and leave. Second, Jaeger must list `scout`. Your numbers differ:

```sh
kubectl exec -n starfleet deploy/shuttle -- curl -s otel-collector-monitoring.observability:8888/metrics | grep -E "^otelcol_(receiver_accepted_spans|exporter_sent_spans)"
kubectl exec -n starfleet deploy/shuttle -- curl -s jaeger.observability:16686/api/v3/services | grep -o '"scout"'
```

```text
otelcol_exporter_sent_spans{exporter="otlp_grpc/jaeger",server_address="jaeger.observability",server_port="4317"} 55
otelcol_receiver_accepted_spans{receiver="otlp/grpc",transport="grpc"} 55
"scout"
```

## Read the symptoms

The two faults gave two different signs, in two different places. The table adds a third fault, a pipeline that names an exporter that is not defined. In that case the new Collector pod stops with `Error`, and the Deployment keeps the old pod running, so traces may still flow while the new configuration never applies.

| Symptom | Where to look | Cause |
| --- | --- | --- |
| The application logs `i/o timeout` to the Collector Service | `kubectl get service` shows a missing port; the Collector log has no `Starting GRPC server` line | A receiver is defined, but no pipeline lists it |
| The Collector log repeats `Exporting failed. Will retry` | The address and port in the `dial tcp` text | The exporter endpoint has the wrong host or port |
| The new Collector pod is in `Error` | `kubectl logs` of that pod: `Error: invalid configuration: service::pipelines::traces: references exporter "otlp_grpc/jaegar" which is not configured` | A pipeline names a part that is not defined |

You can now read a Collector fault from its symptom: the Service ports and the startup lines show which receivers run, the retry lines show where the exporter fails, and the counters show whether spans pass through. Every fix is proved when `scout` appears in Jaeger and the two counters rise together.

## Common pitfalls

> [!WARNING]
> - **Trusting `Running`.** The pod runs while the pipeline is broken. Check the log and the counters.
> - **Fixing the wrong layer first.** While the receiver is unused, no span reaches the exporter, so the exporter fault stays hidden. Fix, wait, look again.
> - **Reading the log of the old pod.** After a bad change two pods can exist. Use `kubectl get pods` and read the log of the pod in `Error`.
> - **Sending `scout` straight to Jaeger.** Spans arrive, but the Collector is bypassed and the pipeline stays broken.

## Your mission: Fix A Broken Collector Pipeline

You can now find out why spans do not reach Jaeger and prove the fix with the Collector counters and the Jaeger API. The mission gives you a Collector that is `Running` and a `scout` whose traces are missing. Fix the Collector so that the traces of `scout` arrive in Jaeger through it.

Pause the playground, then start the lab:

```sh
astrona stop ats-020-playground-030-01
```

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/labs/lab-01
```

The task is on the next page. When you have fixed the pipeline, grade your work:

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

When the lab is done, remove it and start the playground again:

```sh
astrona destroy ats-020-lab-030-01
astrona start ats-020-playground-030-01
```

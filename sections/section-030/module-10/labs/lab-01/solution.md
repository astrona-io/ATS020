# Solution

The Deployment `probe` in `outpost` runs, but Jaeger does not list it. Two settings stop its spans, one behind the other. `OTEL_ENABLED` is `false`, so the program creates no spans. Behind it, `OTEL_EXPORTER_OTLP_ENDPOINT` names a namespace where Jaeger does not run.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-030/module-10/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Read the starting state

The log of the pod says what the program does with its settings. Read it first:

```sh
kubectl -n outpost logs deploy/probe
```

```text
OpenTelemetry is off (OTEL_ENABLED is not true): no spans are created
```

`kubectl set env --list` prints the environment variables of a Deployment without changing anything:

```sh
kubectl -n outpost set env deployment/probe --list
```

```text
# Deployment probe, container probe
TRACE_SERVICE=probe
TARGET_URL=http://relay.outpost:8080
OTEL_ENABLED=false
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger.observability:4318
```

`OTEL_ENABLED` is `false`. The endpoint also looks wrong, but the log cannot show that yet, because the program sends nothing.

## Switch OpenTelemetry on

Set `OTEL_ENABLED` to `true`. `kubectl set env` changes the pod template, so the Deployment controller replaces the pod. Wait for the rollout:

```sh
kubectl -n outpost set env deployment/probe OTEL_ENABLED=true
kubectl -n outpost rollout status deployment/probe --timeout=120s
```

```text
deployment.apps/probe env updated
Waiting for deployment "probe" rollout to finish: 0 out of 1 new replicas have been updated...
Waiting for deployment "probe" rollout to finish: 1 old replicas are pending termination...
deployment "probe" successfully rolled out
```

Wait a few seconds, then read the log of the new pod:

```sh
kubectl -n outpost logs deploy/probe --tail=3
```

```text
Span export to http://jaeger.observability:4318/v1/traces failed: <urlopen error [Errno -2] Name does not resolve>
Span export to http://jaeger.observability:4318/v1/traces failed: <urlopen error [Errno -2] Name does not resolve>
Span export to http://jaeger.observability:4318/v1/traces failed: <urlopen error [Errno -2] Name does not resolve>
```

The program now creates spans, but the cluster Domain Name System (DNS) has no name `jaeger.observability`. The first fault hid this second one.

## Point the endpoint at Jaeger

Find the namespace and the ports of the Jaeger Service:

```sh
kubectl get service -A | grep jaeger
```

```text
tracing       jaeger       ClusterIP   10.96.32.82   <none>        4317/TCP,4318/TCP,16686/TCP   3m11s
```

Jaeger runs in `tracing`. The program sends OTLP over HTTP, which Jaeger receives on `4318`; `4317` is OTLP over gRPC. `OTEL_EXPORTER_OTLP_ENDPOINT` is the base address with no path, because the program adds `/v1/traces` itself:

```sh
kubectl -n outpost set env deployment/probe OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger.tracing:4318
kubectl -n outpost rollout status deployment/probe --timeout=120s
```

```text
deployment.apps/probe env updated
Waiting for deployment "probe" rollout to finish: 1 old replicas are pending termination...
deployment "probe" successfully rolled out
```

The log of the new pod has no export errors:

```sh
kubectl -n outpost logs deploy/probe --tail=3
```

```text
OpenTelemetry is on: sending spans to http://jaeger.tracing:4318/v1/traces
```

Jaeger now lists `probe` next to its own service `jaeger`. The **Jaeger** tab shows the same list; in a terminal, read it from the query API on the forwarded port `26686`:

```sh
curl -s http://127.0.0.1:26686/api/v3/services
```

```text
{"services":["jaeger","probe"]}
```

## Export the exceptions

The version 3 query API needs a time range. Build one that covers the last five minutes. The `date -v` form is for macOS; on Linux, use `date -u -d '-5 min' +%Y-%m-%dT%H:%M:%SZ` and `date -u -d '+1 min' +%Y-%m-%dT%H:%M:%SZ`:

```sh
START=$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u -v+1M +%Y-%m-%dT%H:%M:%SZ)
TRACES_URL="http://127.0.0.1:26686/api/v3/traces?query.service_name=probe&query.start_time_min=$START&query.start_time_max=$END&query.search_depth=5"
curl -s "$TRACES_URL" | jq '[.result.resourceSpans[].scopeSpans[].spans[] | {name, status}] | .[0]'
```

```json
{
  "name": "call-target",
  "status": {
    "message": "URLError: <urlopen error [Errno -2] Name does not resolve>",
    "code": 2
  }
}
```

Status code `2` is `ERROR`. The request to `TARGET_URL` fails, and the program records the failure as an `exception` event in each span. Keep only those events and save them:

```sh
curl -s "$TRACES_URL" | jq '[.result.resourceSpans[].scopeSpans[].spans[].events[] | select(.name == "exception")]' > /tmp/ats-020-exception.json
jq 'length' /tmp/ats-020-exception.json
jq '.[0] | {name, attributes: [.attributes[] | select(.key != "exception.stacktrace")]}' /tmp/ats-020-exception.json
```

```text
5
```

```json
{
  "name": "exception",
  "attributes": [
    {
      "key": "exception.message",
      "value": {
        "stringValue": "<urlopen error [Errno -2] Name does not resolve>"
      }
    },
    {
      "key": "exception.type",
      "value": {
        "stringValue": "URLError"
      }
    }
  ]
}
```

The last command hides the long `exception.stacktrace` attribute only on screen; the file keeps it. Each event in the file is a copy of an event Jaeger holds, so the grader can match it.

## Submit

When the watching terminal shows every check as passed, stop it with `Ctrl+C` and grade the lab once:

```sh
astrona submit -c sections/section-030/module-10/labs/lab-01
```

The graders check four things: `OTEL_ENABLED` is `true` and the new pod is ready; the endpoint is the Service `jaeger` in `tracing` on port `4318`; Jaeger holds recent `probe` spans with an `exception` event; and every event in `/tmp/ats-020-exception.json` matches an exception that Jaeger holds for `probe`. A changed `TARGET_URL` fails every check, because the failing request is the source of the evidence.

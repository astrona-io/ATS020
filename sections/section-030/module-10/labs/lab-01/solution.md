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

The log of the new pod shows that each span reaches Jaeger, with no export errors:

```sh
kubectl -n outpost logs deploy/probe | head -2
```

```text
OpenTelemetry is on: sending spans to http://jaeger.tracing:4318/v1/traces
Span sent: trace_id=71eb0f218008e90f62a735211fc5f9be
```

Jaeger now lists `probe` next to its own service `jaeger`. The **Jaeger** tab shows the same list; in the terminal, read it from the query API. The lab forwards Jaeger to port `26686` of your machine, and the terminal reaches your machine by the name `host.docker.internal`:

```sh
curl -s http://host.docker.internal:26686/api/v3/services
```

```text
{"services":["jaeger","probe"]}
```

## Export the exception

With OpenTelemetry on, `probe` prints the trace ID of every span it sends to Jaeger. Read the last lines of its log:

```sh
kubectl -n outpost logs deploy/probe --tail=3
```

```text
Span sent: trace_id=a0731d01872898237c3e8d5342090b92
Span sent: trace_id=dc683467134689431d087234569a7783
Span sent: trace_id=145f52dfc694bf640f78814c8caa9f75
```

Your trace IDs differ. The Jaeger query API returns one trace by its full ID at `/api/v3/traces/<TRACE_ID>`, with no time range. Take the last ID and look at what Jaeger returns for that trace:

```sh
TRACE_ID=$(kubectl -n outpost logs deploy/probe --tail=1 | sed 's/.*trace_id=//')
curl -s "http://host.docker.internal:26686/api/v3/traces/$TRACE_ID" | jq .
```

The response below is shortened: the long `exception.stacktrace` value is cut to `...`, and small objects are put on one line.

```json
{
  "result": {
    "resourceSpans": [
      {
        "resource": {
          "attributes": [
            { "key": "service.name", "value": { "stringValue": "probe" } }
          ]
        },
        "scopeSpans": [
          {
            "scope": { "name": "astrona-trace-fixture" },
            "spans": [
              {
                "traceId": "145f52dfc694bf640f78814c8caa9f75",
                "spanId": "ef24c9b63333b6aa",
                "name": "call-target",
                "kind": 3,
                "startTimeUnixNano": "1794425125390128383",
                "endTimeUnixNano": "1794425125399694683",
                "attributes": [
                  { "key": "target.url", "value": { "stringValue": "http://relay.outpost:8080" } }
                ],
                "events": [
                  {
                    "timeUnixNano": "1794425125395461388",
                    "name": "exception",
                    "attributes": [
                      { "key": "exception.message", "value": { "stringValue": "<urlopen error [Errno -2] Name does not resolve>" } },
                      { "key": "exception.stacktrace", "value": { "stringValue": "Traceback (most recent call last):\n ..." } },
                      { "key": "exception.type", "value": { "stringValue": "URLError" } }
                    ]
                  }
                ],
                "status": {
                  "message": "URLError: <urlopen error [Errno -2] Name does not resolve>",
                  "code": 2
                }
              }
            ]
          }
        ]
      }
    ]
  }
}
```

The response is the whole trace: the resource (`service.name`), the span `call-target` with its attributes and status, and, inside the span, its `events` list. The request to `TARGET_URL` fails, and the program records the failure as the one event in that list, named `exception`. The task asks for that event only, not the whole response. Use `jq` to walk down to the `events` list and keep the event named `exception`:

```sh
curl -s "http://host.docker.internal:26686/api/v3/traces/$TRACE_ID" | jq '.result.resourceSpans[].scopeSpans[].spans[].events[] | select(.name == "exception")' > /workspace/ats-020-exception.json
cat /workspace/ats-020-exception.json
```

The file now holds one JSON object. The output below is shortened the same way:

```json
{
  "timeUnixNano": "1794425125395461388",
  "name": "exception",
  "attributes": [
    {
      "key": "exception.message",
      "value": {
        "stringValue": "<urlopen error [Errno -2] Name does not resolve>"
      }
    },
    {
      "key": "exception.stacktrace",
      "value": {
        "stringValue": "Traceback (most recent call last):\n ..."
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

The file starts with `"timeUnixNano"` and `"name": "exception"`, not with `"result"`. If you save the whole response instead, the grader fails with "must hold only the exception span event, not the whole API response". The event in the file is a copy of an event Jaeger holds, so the grader can match it.

## Submit

When the watching terminal shows every check as passed, stop it with `Ctrl+C` and grade the lab once:

```sh
astrona submit -c sections/section-030/module-10/labs/lab-01
```

The graders check four things: `OTEL_ENABLED` is `true` and the new pod is ready; the endpoint is the Service `jaeger` in `tracing` on port `4318`; Jaeger holds recent `probe` spans with an `exception` event; and the event in `/workspace/ats-020-exception.json` matches an exception that Jaeger holds for `probe`. A changed `TARGET_URL` fails every check, because the failing request is the source of the evidence.

# Solution

The Deployment `probe` in `outpost` sends no spans to Jaeger for two reasons. `OTEL_ENABLED` is `false`, so the program creates no spans. `OTEL_EXPORTER_OTLP_ENDPOINT` points at `jaeger.observability`, but Jaeger runs in the namespace `tracing`.

## Tasks 1 and 2: fix the two environment variables

Check the current values first. `kubectl set env --list` prints the environment variables of a Deployment without changing anything:

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

Set both variables with one command. The endpoint is the Service `jaeger` in `tracing` on port `4318`, the port for OTLP over HTTP. It has no path, because the program adds `/v1/traces` itself. `kubectl set env` changes the pod template, so the Deployment controller replaces the pod. Wait for the new pod:

```sh
kubectl -n outpost set env deployment/probe OTEL_ENABLED=true OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger.tracing:4318
kubectl -n outpost rollout status deployment/probe --timeout=180s
```

```text
deployment.apps/probe env updated
Waiting for deployment "probe" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "probe" rollout to finish: 1 old replicas are pending termination...
deployment "probe" successfully rolled out
```

The log of the new pod proves that each span reaches Jaeger. Every line gives the trace ID of one span:

```sh
kubectl -n outpost logs deploy/probe --tail=3
```

```text
Span sent: trace_id=a0731d01872898237c3e8d5342090b92
Span sent: trace_id=dc683467134689431d087234569a7783
Span sent: trace_id=145f52dfc694bf640f78814c8caa9f75
```

Your trace IDs differ. If you see `Span export to ... failed` instead, the endpoint is still wrong.

## Task 3: save the exception event

The lab forwards the Jaeger query API to port `26686` of your machine. The terminal reaches your machine by the name `host.docker.internal`. The address `/api/v3/traces/<TRACE_ID>` returns one whole trace by its full 32-character ID, with no time range.

You need one full trace ID of `probe`. There are two places to find it:

- **The log of `probe`.** Each `Span sent: trace_id=...` line holds a full trace ID. Copy the part after `trace_id=`.
- **The Jaeger tab.** In **Search**, pick the service `probe` and click **Find Traces**. The list shows each trace as `probe: call-target` with a short ID of 7 characters, for example `119622c`. Click a trace to open it. The address now ends with `/trace/` and the full ID, for example `/trace/119622c27865e7d46d3c5a19b662df9c`. Copy the full ID from the address. The short ID in the list and in the page title does not work with the API: Jaeger answers `404`.

The task asks for one event inside that trace, not the whole response. The response holds the span in `.result.resourceSpans[].scopeSpans[].spans[]`, and each span keeps its events in `events[]`. Put your trace ID in the address, and let `jq` keep only the event named `exception`. This example uses the trace ID `a4e1c900c778f5bb80e91337a17149fe`; use your own:

```sh
curl -s http://host.docker.internal:26686/api/v3/traces/a4e1c900c778f5bb80e91337a17149fe | jq '.result.resourceSpans[].scopeSpans[].spans[].events[] | select(.name == "exception")' > /workspace/ats-020-exception.json
cat /workspace/ats-020-exception.json
```

Write the path as `/api/v3/traces/`, with an `s`. Jaeger answers `/api/v3/trace/` with the text `404 page not found`, and `jq` then fails with `Invalid numeric literal`. The filter starts with `.result.resourceSpans[]`, not `.result[]`, because `result` is an object, not a list.

The output below is shortened: the long `exception.stacktrace` value is cut to `...`.

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

The program sends each request to `TARGET_URL`, and no Service `relay` exists in `outpost`. So every request fails, and the program records the failure as this `exception` event in the span. The file must start with `"timeUnixNano"` and `"name": "exception"`, not with `"result"`. If it starts with `"result"`, you saved the whole response, and the grader fails.

## Submit

Grade the lab:

```sh
astrona submit -c sections/section-030/module-10/labs/lab-01
```

The graders check four things. `OTEL_ENABLED` is `true` and the new pod is ready. The endpoint is the Service `jaeger` in `tracing` on port `4318`. Jaeger holds recent `probe` spans with an `exception` event. The event in `/workspace/ats-020-exception.json` matches an exception that Jaeger holds for `probe`. A plain `astrona submit` ends the attempt and deletes the lab. To check your progress without ending the attempt, run `astrona submit --watch -c sections/section-030/module-10/labs/lab-01` instead.

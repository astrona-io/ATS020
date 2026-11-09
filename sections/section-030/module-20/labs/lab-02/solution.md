# Solution Guide: Identify the Slow Operation in a Trace

## Find a slow request

The lab starts with working auto-instrumentation. In a second terminal, expose Jaeger's API:

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

In your first terminal, save a slow trace. The duration filter selects requests with at least one `relay` span lasting 500 milliseconds or more:

```sh
curl -fsSG http://127.0.0.1:16686/api/v3/traces \
  --data-urlencode 'query.service_name=relay' \
  --data-urlencode 'query.start_time_min=2020-01-01T00:00:00Z' \
  --data-urlencode 'query.start_time_max=2100-01-01T00:00:00Z' \
  --data-urlencode 'query.search_depth=1' \
  --data-urlencode 'query.duration_min=500ms' > /tmp/ats020-slow-trace.json
```

Print the span relationships and timings from the saved response:

```sh
jq -c '.result.resourceSpans[] |
  (.resource.attributes[] | select(.key == "service.name") | .value.stringValue) as $service |
  .scopeSpans[].spans[] |
  {service: $service, name, kind, traceId, spanId, parentSpanId,
   durationMs: (((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) / 1000000 | round)}' \
  /tmp/ats020-slow-trace.json
```

If the file has no spans or only one service, wait and repeat the search. Both services export in batches. Use a result with one trace identifier and the complete chain: `relay` server → `relay` client → `scout` server → `scout` internal handler. Each child must name the preceding span as its parent.

## Identify the delayed work

The internal `delayHandler` span in `scout` lasts about a second. The enclosing `scout` request and the two `relay` spans include that same wait. Picking the longest request span would identify where the delay is observed, without identifying the downstream work that explains it.

Extract the internal handler's identifiers and calculate its elapsed duration from the saved timestamps:

```sh
jq '.result.resourceSpans[] |
  (.resource.attributes[] | select(.key == "service.name") | .value.stringValue) as $service |
  .scopeSpans[].spans[] |
  select($service == "scout" and .name == "delayHandler" and .kind == 1) |
  {service: $service, name, traceId, spanId,
   durationMs: (((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)) / 1000000 | round)}' \
  /tmp/ats020-slow-trace.json > /tmp/ats020-slow-span.json
```

Read the finding before submitting:

```sh
cat /tmp/ats020-slow-span.json
```

One tested run produced:

```json
{
  "service": "scout",
  "name": "delayHandler",
  "traceId": "d3b63307990ecd134ee7020893435a89",
  "spanId": "63c8a71c5d9ad6bd",
  "durationMs": 1001
}
```

The duration should be close to 1000 milliseconds. Your identifiers must come from your own saved trace. The grader checks those identifiers and timings against Jaeger's live data, so keep the lab running until submission completes.

## Submit the evidence

```sh
astrona submit -c sections/section-030/module-20/labs/lab-02
```

Both checks must pass: the saved trace matches Jaeger and contains the complete parent chain, and the finding names the slow internal operation with its measured duration.

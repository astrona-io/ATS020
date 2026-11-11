# Question

Solve this question on: `terminal`

Some requests to `relay` in `starfleet` take about a second. Each request calls `scout` before returning. Both services already send spans through the Collector to Jaeger, and `shuttle` generates normal and slow traffic.

Find the downstream operation that explains a slow request. The tracing setup works; your task is to diagnose the delay and preserve the evidence.

## Tasks

1. Find a slow trace with the complete parent chain from the incoming `relay` request, through its outgoing request, to the `scout` request and its internal handler.
2. Save that one trace's full Jaeger v3 JSON response to `/tmp/ats020-slow-trace.json`. Preserve the returned span fields.
3. Identify the internal operation that explains the delay. Calculate its elapsed duration from the saved start and end timestamps.
4. Save your finding as one JSON object in `/tmp/ats020-slow-span.json`, with these fields:

| Field | Required value |
| --- | --- |
| `service` | The service running the internal operation that explains the delay |
| `name` | That operation's exact span name |
| `traceId` | Its trace identifier |
| `spanId` | Its span identifier |
| `durationMs` | Its elapsed duration in milliseconds, rounded to the nearest whole millisecond |

Choose the internal operation doing the delayed work, rather than an enclosing request that waits for it. Calculate its duration from the saved span's start and end timestamps.

## Constraints

- Inspect the existing workloads and traces. Do not change the applications, traffic generator, instrumentation, Collector, or Jaeger.
- Export a trace from this lab, not the playground or a course example. Include exactly one trace and both services.
- Keep Jaeger running until you submit. It uses in-memory storage, and the grader compares your evidence with that stored trace.

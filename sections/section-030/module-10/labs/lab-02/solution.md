# Solution Walkthrough

Search Jaeger for each tag, change the two Deployments the search points to,
then save five traces to a file. Jaeger stays untouched. The third workload,
`shuttle`, needs no change.

| Goal | Where it lives | What to inspect |
| --- | --- | --- |
| Find a service by tag | Jaeger web interface or `/api/v3/traces` | `service.name` in the response |
| Lower the delay | Deployment environment | `RESPONSE_DELAY_MS` |
| Add capacity | Deployment | Desired and ready replicas |
| Export exactly 5 traces | `/api/v3/traces` with `query.searchDepth=5` | Distinct `traceId` values |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-10/labs/lab-02
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

Before you change anything, expect `delay-reduced`, `capacity-increased`,
`export-count` and `export-live` to fail. Nothing is changed yet, and the file
does not exist.

## Step 1: Find the services by tag

Forward the Service in a separate terminal and leave it running:

```sh
kubectl -n observability port-forward service/jaeger 16686:16686
```

To use the web interface, open `http://127.0.0.1:16686`. On the Search page,
choose **All Services**. Type `incident.code=retry-storm` in the field that
Jaeger 2.22.0 labels **Attributes**, then select **Find Traces**. Each row names
the service of a trace. Repeat with `incident.code=queue-pressure`.

For an older exam server, the reading section **Search through the older Jaeger API** explains the legacy routes and the command that detects the available API.

To use the API, define this helper in your first terminal. The time range is
required, so it uses a wide one. `query.attributes` is a JSON (JavaScript Object
Notation) object, and `--data-urlencode` makes it safe to put in a URL:

```sh
find_service_by_tag() {
  curl -fsSG http://127.0.0.1:16686/api/v3/traces \
    --data-urlencode "query.attributes={\"incident.code\":\"$1\"}" \
    --data-urlencode 'query.startTimeMin=2020-01-01T00:00:00Z' \
    --data-urlencode 'query.startTimeMax=2100-01-01T00:00:00Z' \
    --data-urlencode 'query.searchDepth=20' |
    jq -r '[.result.resourceSpans[].resource.attributes[] | select(.key == "service.name") | .value.stringValue] | unique | .[]'
}
find_service_by_tag retry-storm
find_service_by_tag queue-pressure
```

Look for one service name per call. The manifest sends `retry-storm` from
`scout` and `queue-pressure` from `probe`, and the commands below use those
names. No check changes yet.

## Step 2: Lower the delay on scout

Change the variable and wait for the new pod:

```sh
kubectl -n starfleet set env deployment/scout RESPONSE_DELAY_MS=20
kubectl -n starfleet rollout status deployment/scout --timeout=180s
```

Kubernetes replaces the pod, because the pod template changed. Jaeger keeps the
older traces, so the service still has them after the rollout.

**Run the check:** the watch terminal shows `delay-reduced` passing.

## Step 3: Scale probe

Set three replicas and wait for them:

```sh
kubectl -n starfleet scale deployment probe --replicas=3
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet get deployments scout probe shuttle
```

Look for three ready `probe` replicas and one ready replica each for `scout` and
`shuttle`.

**Run the check:** the watch terminal shows `capacity-increased` passing.

## Step 4: Export exactly five traces

Ask for the service and limit the search to five traces. Send the response
straight to the file, so it stays unchanged:

```sh
curl -fsS 'http://127.0.0.1:16686/api/v3/traces?query.serviceName=scout&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2100-01-01T00:00:00Z&query.searchDepth=5' > /tmp/ats-020-incident-traces.json
```

`query.searchDepth` limits the number of traces, not spans. Count what you saved
by trace ID, because a trace can fill more than one `resourceSpans` entry:

```sh
jq '[.result.resourceSpans[].scopeSpans[].spans[].traceId] | unique | length' /tmp/ats-020-incident-traces.json
jq -r '[.result.resourceSpans[].resource.attributes[] | select(.key == "service.name") | .value.stringValue] | unique | .[]' /tmp/ats-020-incident-traces.json
```

The first command must print `5`, and the second must print only `scout`. If the
first prints less than `5`, wait a few seconds and run the export again.

**Run the check:** the watch terminal shows all four checks passing. Press Ctrl-C to
stop the watch, then submit once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-10/labs/lab-02
```

## If a check stays red

- **`delay-reduced`: the wrong Deployment changed.** Repeat the tag search. Put
  back any variable you changed on another Deployment.
- **`capacity-increased`: `shuttle` has more than one replica.** Only the
  `queue-pressure` service needs capacity. Scale `shuttle` back to `1`.
- **`export-count`: the shape is wrong.** Save the `/api/v3/traces` response and
  nothing else. Output from `jq`, the `/api/v3/trace-summaries` route or a copy
  from the browser has a different shape.
- **`export-count`: the number is wrong.** Set `query.searchDepth=5` and set
  `query.serviceName` to the `retry-storm` service.
- **`export-live`: a trace is missing.** The Jaeger pod restarted, or the file is
  from another run. In-memory storage lost those traces, so export them again.

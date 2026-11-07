# Solution Walkthrough

Find the service whose spans end with an error, copy the exception events of
one of its traces to a file, then repair the address its Deployment calls.
Jaeger stays untouched. The two other workloads, `scout` and `shuttle`, need no
change.

| Goal | Where it lives | What to inspect |
| --- | --- | --- |
| Name the failing service | Jaeger web interface or `/api/v3/traces` | `status.code` of each span |
| Export the exceptions | `spans[].events[]` in `/api/v3/traces` | Events named `exception` |
| Fix the cause | Deployment environment | `TARGET_URL` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/labs/lab-03
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

Before you change anything, expect `service-named`, `exceptions-exported` and
`cause-fixed` to fail. The files do not exist, and the Deployment still calls
the wrong address.

## Step 1: Find the service with error spans

Forward the Service in a separate terminal and leave it running:

```sh
kubectl -n observability port-forward service/jaeger 16686:16686
```

To use the web interface, open `http://127.0.0.1:16686`. On the Search page,
choose **All Services**, type `error=true` in the field that Jaeger 2.22.0
labels **Attributes**, then select **Find Traces**. Jaeger marks a span whose
status is `ERROR` with the tag `error=true`, and the result rows show a red
error marker and the service name.

To use the API, ask for a few traces of each service and count the spans whose
`status.code` is the error code. In OTLP (OpenTelemetry Protocol) JSON the
status code `2` means `ERROR`; some servers spell it `STATUS_CODE_ERROR`, so
the filter accepts both. The time range is required, so the helper uses a wide
one:

```sh
error_spans_of() {
  curl -fsSG http://127.0.0.1:16686/api/v3/traces \
    --data-urlencode "query.serviceName=$1" \
    --data-urlencode 'query.startTimeMin=2020-01-01T00:00:00Z' \
    --data-urlencode 'query.startTimeMax=2100-01-01T00:00:00Z' \
    --data-urlencode 'query.searchDepth=20' |
    jq '[.result.resourceSpans[].scopeSpans[].spans[] | select((.status.code // 0) as $code | $code == 2 or $code == "STATUS_CODE_ERROR")] | length'
}
for service in $(curl -fsS http://127.0.0.1:16686/api/v3/services | jq -r '.services[]'); do
  echo "$service: $(error_spans_of "$service")"
done
```

Look for one service with a count above `0` and two with `0`. The manifest
sends the error spans from `probe`, and the commands below use that name. Write
only the name to the answer file:

```sh
echo probe > /tmp/ats-020-error-service.txt
```

**Run the check:** the watch terminal shows `service-named` passing.

## Step 2: Export the exception events

Each error span of `probe` carries one span event named `exception`. Read a
few traces of the service, keep only the error spans, and collect their
`exception` events into one array. Send the array to the file, so the event
objects stay as the API returned them:

```sh
curl -fsSG http://127.0.0.1:16686/api/v3/traces \
  --data-urlencode 'query.serviceName=probe' \
  --data-urlencode 'query.startTimeMin=2020-01-01T00:00:00Z' \
  --data-urlencode 'query.startTimeMax=2100-01-01T00:00:00Z' \
  --data-urlencode 'query.searchDepth=5' |
  jq '[.result.resourceSpans[].scopeSpans[].spans[] | select((.status.code // 0) as $code | $code == 2 or $code == "STATUS_CODE_ERROR") | .events[]? | select(.name == "exception")]' > /tmp/ats-020-exceptions.json
```

Check what you saved. The first command prints the number of events, at least
`1`. The second prints the exception type and message of each event, and the
message names the host that did not resolve:

```sh
jq length /tmp/ats-020-exceptions.json
jq -r '.[] | [.attributes[] | select(.key == "exception.type" or .key == "exception.message") | .value.stringValue] | join(": ")' /tmp/ats-020-exceptions.json
```

**Run the check:** the watch terminal shows `exceptions-exported` passing.

## Step 3: Fix the address probe calls

The exception message says that the host `relay.starfleet` does not resolve.
Read the variable and the Services in the namespace:

```sh
kubectl -n starfleet set env deployment/probe --list | grep TARGET_URL
kubectl -n starfleet get services
```

```text
TARGET_URL=http://relay.starfleet:8080
NAME      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
shuttle   ClusterIP   10.96.153.40   <none>        8080/TCP   9m
```

No Service named `relay` exists; `shuttle` does, on port `8080`. Point the
variable at it and wait for the new pod:

```sh
kubectl -n starfleet set env deployment/probe TARGET_URL=http://shuttle.starfleet:8080
kubectl -n starfleet rollout status deployment/probe --timeout=180s
```

Kubernetes replaces the pod, because the pod template changed. Jaeger keeps the
older error traces, so the exported evidence is still there. After a few
seconds the new pod sends traces whose spans have no error status. Run the
helper from step 1 again with a search depth of `3` to see the newest traces
return `0`.

**Run the check:** the watch terminal shows all three checks passing. Press
Ctrl-C to stop the watch, then submit once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/labs/lab-03
```

## If a check stays red

- **`service-named`: the file holds more than a name.** Write only the service
  name, nothing else. A trailing newline is fine.
- **`exceptions-exported`: the shape is wrong.** Save a JSON array of the event
  objects only. The whole API response, a single event object or a list of
  messages has a different shape.
- **`exceptions-exported`: an event is unknown.** The events must come from the
  running Jaeger. A file typed by hand, or one kept from another run, does not
  match. Export again from the API.
- **`cause-fixed`: the new traces still fail.** Check the variable with
  `kubectl -n starfleet set env deployment/probe --list`. The value must be
  exactly `http://shuttle.starfleet:8080`, with the port.
- **`cause-fixed`: the rollout did not finish.** Read
  `kubectl -n starfleet get pods -l app=probe` and the pod events. A typo in
  the variable name creates a second variable and leaves the old one in place.

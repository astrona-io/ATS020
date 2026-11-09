# Question

Solve this question on: `terminal`

## Scenario

Three workloads in the `starfleet` namespace send spans to Jaeger 2.23.0, which
runs in the `observability` namespace. The Service `jaeger` serves the web
interface and the query application programming interface (API) on port
`16686`. A span is one timed step of a request, and a trace is the set of spans
of one request. Each Deployment in `starfleet` has the same name as the service
it sends spans for.

One of the three services sends spans that end with the status `ERROR`. Each
of those spans carries a span event named `exception`, which records the error
with the attributes `exception.type`, `exception.message` and
`exception.stacktrace`. The platform team needs the service name, the recorded
exceptions as a file, and the cause fixed. Traces live only in the memory of
Jaeger, so do not restart it.

## Tasks

1. **Name the failing service.** Use the Jaeger web interface, the API, or both,
   to find the one service whose spans carry the status `ERROR`. Write only its
   name to `/tmp/ats-020-error-service.txt`.
2. **Export the exceptions.** Read at least one trace of that service from
   `GET /api/v3/traces` and save its `exception` span events to
   `/tmp/ats-020-exceptions.json`. The file must be a JSON array that holds
   only the event objects, as the API returns them under `spans[].events[]`,
   with their `name` and `attributes` unchanged.
3. **Fix the cause.** The Deployment of that service sends a request to the
   address in its environment variable `TARGET_URL`. The address names a
   Service that does not exist. Set `TARGET_URL` to
   `http://shuttle.starfleet:8080`, the Service that does exist, and wait
   until the new pod runs. Keep the Deployment at one ready replica.

Keep the other environment variables of every Deployment unchanged. Do not
change the Deployments `scout` and `shuttle`.

The grader reads both files, compares every exported event with the traces in
the running Jaeger, and checks that the traces of the new pod have no error.

# Question

Solve this question on: `terminal`

## Scenario

Three workloads in the `starfleet` namespace send spans to Jaeger 2.23.0, which
runs in the `observability` namespace. The Service `jaeger` serves the web
interface and the query application programming interface (API) on port
`16686`. A span is one timed step of a request, and a trace is the set of spans
of one request. Each span carries a tag, which is a key-value pair, named
`incident.code`.

An incident report gives two tag values but does not name the services. Each
Deployment in `starfleet` has the same name as the service it sends spans for.
Traces live only in the memory of Jaeger, so do not restart it.

## Tasks

1. **Find the services.** Use the Jaeger web interface, the API, or both, to
   find the service whose spans carry `incident.code=retry-storm` and the
   service whose spans carry `incident.code=queue-pressure`.
2. **Reduce the delay.** On the Deployment for the `retry-storm` service, set
   the environment variable `RESPONSE_DELAY_MS` to `20`. Keep it at one ready
   replica.
3. **Add capacity.** Scale the Deployment for the `queue-pressure` service to
   **three ready replicas**.
4. **Export the evidence.** Save **exactly 5 traces** of the `retry-storm`
   service to `/tmp/ats-020-incident-traces.json`. The file must be the
   unchanged JSON response of `GET /api/v3/traces`, with every trace from that
   service only.

Keep the other environment variables of every Deployment unchanged. Keep the
`shuttle` Deployment at one ready replica unless a tag search points to it.

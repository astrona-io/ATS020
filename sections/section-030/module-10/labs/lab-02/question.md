# Question

Solve this question on: `terminal`

Three Deployments in the `starfleet` namespace, `scout`, `probe` and `shuttle`, send spans to Jaeger 2.23.0 in the `observability` namespace. Each Deployment has the same name as the service it sends spans for. The Service `jaeger` serves the web interface and query API on port `16686`. Every span carries the tag `incident.code`. An incident report names two tag values, `retry-storm` and `queue-pressure`, but not the services.

## Tasks

1. Find the service whose spans carry `incident.code=retry-storm` and the service whose spans carry `incident.code=queue-pressure`. Use the Jaeger web interface, the API, or both.
2. On the Deployment of the `retry-storm` service, set the environment variable `RESPONSE_DELAY_MS` to `20`. Keep it at one ready replica.
3. Scale the Deployment of the `queue-pressure` service to three ready replicas.
4. Save exactly 5 traces of the `retry-storm` service to `/tmp/ats-020-incident-traces.json`. The file must be the unchanged JSON response of `GET /api/v3/traces` and hold traces of that service only.

## Constraints

- Keep the other environment variables of every Deployment as they are.
- Keep `shuttle` at one ready replica unless a tag search points to it.
- Do not restart Jaeger. It keeps traces only in memory.

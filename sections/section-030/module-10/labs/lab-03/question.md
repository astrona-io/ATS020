# Question

Solve this question on: `terminal`

Three Deployments in the `starfleet` namespace, `scout`, `probe` and `shuttle`, send spans to Jaeger 2.23.0 in the `observability` namespace. Each Deployment has the same name as the service it sends spans for. The Service `jaeger` serves the web interface and query API on port `16686`. The spans of one service end with the status `ERROR` and carry a span event named `exception`, with the attributes `exception.type`, `exception.message` and `exception.stacktrace`.

## Tasks

1. Find the service whose spans carry the status `ERROR`. Use the Jaeger web interface, the API, or both. Write only its name to `/tmp/ats-020-error-service.txt`.
2. Read at least one trace of that service from `GET /api/v3/traces` and save its `exception` span events to `/tmp/ats-020-exceptions.json`, as a JSON array of the event objects exactly as the API returns them under `spans[].events[]`.
3. The Deployment of that service sends a request to the address in its environment variable `TARGET_URL`, and that address names a Service that does not exist. Set `TARGET_URL` to `http://shuttle.starfleet:8080` and wait until the new pod is ready. The new traces of the service must have no error.

## Constraints

- Keep the other environment variables of every Deployment as they are, and keep the Deployment at one ready replica.
- Do not change the Deployments `scout` and `shuttle`.
- Do not restart Jaeger. It keeps traces only in memory, and the grader compares the exported events with the running Jaeger.

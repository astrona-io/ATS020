# Finding a Service by Tag

An incident report names `incident.code=slow-scan`, but does not name a service. If that value is recorded on spans, Jaeger can find the matching traces and show which services produced them. A **tag** is a key-value detail on a span; OpenTelemetry calls it an **attribute**.

You will create two sets of tagged traces and search them through Jaeger's web interface and application programming interface (API). The examples use known values so you can check each search result.

## Create traces with known attributes

Jaeger 2.22 exposes its interface and API through the `jaeger` Service on port `16686`. Reuse an existing port-forward if one is still running.

<!-- astrona:playground:renew -->

Otherwise, start this command in a second terminal and leave it running:

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

In your first terminal, run `telemetrygen`, a tool that creates test spans and sends them using the OpenTelemetry Protocol (OTLP). The first run reports the service name `scout` with `incident.code=slow-scan`; the second reports `shuttle` with `incident.code=queue-full`:

```sh
kubectl -n observability run telemetrygen --restart=Never --rm -i --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 -- traces --otlp-insecure --otlp-endpoint jaeger.observability:4317 --service scout --traces 6 --telemetry-attributes incident.code=\"slow-scan\"
kubectl -n observability run telemetrygen --restart=Never --rm -i --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 -- traces --otlp-insecure --otlp-endpoint jaeger.observability:4317 --service shuttle --traces 6 --telemetry-attributes incident.code=\"queue-full\"
```

Each temporary pod creates six traces, sends them directly to Jaeger, and exits. `--telemetry-attributes` adds the span attribute; the escaped quotes make its value a string. `--otlp-insecure` matches the playground's unencrypted receiver. Allow a few seconds for Jaeger to store the spans.

These are generated traces using the workload names. They provide search data; they do not show an actual fault in either workload.

## Search in the web interface

Open `http://127.0.0.1:16686` and choose **All Services** on the Search page. Enter `incident.code=slow-scan` in **Attributes**, then select **Find Traces**. Older interfaces call this field **Tags**.

The matching rows should name `scout`. Repeat with `incident.code=queue-full` and look for `shuttle`. Each result row represents a trace, and **Limit Results** controls how many traces the interface requests. Multiple attribute conditions are separated by spaces and must all match.

## Search through the API

The API makes the search result available to shell commands. First list the services Jaeger knows:

```sh
curl -fsS http://127.0.0.1:16686/api/v3/services | jq -c .services
```

The list should include `scout` and `shuttle`. The `/api/v3/traces` route searches their traces using these parameters:

| Parameter | Meaning |
| --- | --- |
| `query.attributes` | Attribute conditions as a JavaScript Object Notation (JSON) object |
| `query.startTimeMin` | Earliest trace start time to include |
| `query.startTimeMax` | Latest trace start time to include |
| `query.searchDepth` | Maximum number of traces requested |

Define a helper that searches for an attribute and prints service names from the response:

```sh
find_services_by_tag() {
  curl -fsSG http://127.0.0.1:16686/api/v3/traces \
    --data-urlencode "query.attributes={\"$1\":\"$2\"}" \
    --data-urlencode 'query.startTimeMin=2020-01-01T00:00:00Z' \
    --data-urlencode 'query.startTimeMax=2100-01-01T00:00:00Z' \
    --data-urlencode 'query.searchDepth=20' |
    jq -r '[.result.resourceSpans[].resource.attributes[] | select(.key == "service.name") | .value.stringValue] | unique | .[]'
}
find_services_by_tag incident.code slow-scan
find_services_by_tag incident.code queue-full
```

The first call should print `scout`; the second should print `shuttle`. `curl -G` puts the values in the query string, and `--data-urlencode` encodes the JSON safely. Both time bounds are required. The wide range suits a temporary playground; restrict it to the incident window when investigating production data.

The `jq` filter reads `service.name` from each **resource**, which describes the source of the spans. It removes duplicate names with `unique`. A returned trace can include several services, so inspect which span carries the matching attribute before deciding which service needs attention.

The playground's in-memory storage supports searching without a service name. Other storage backends may require `query.serviceName`; when they do, list services and search each candidate. Jaeger 2.22 also accepts older parameter spellings such as `query.service_name`, but the examples here use the current camel-case names.

## Recognise the older query API

An existing cluster may run Jaeger 1.x or Jaeger 2.0 through 2.20. Those releases serve the older `/api/services` and `/api/traces` search routes. Jaeger 2.21 removed these routes. Probe the service endpoints before choosing a search form:

```sh
curl -sS -w '\n%{url_effective}: HTTP %{http_code}\n' \
  http://127.0.0.1:16686/api/services \
  http://127.0.0.1:16686/api/v3/services
```

On the playground, expect a Hypertext Transfer Protocol (HTTP) `404` response from `/api/services` and `200` from `/api/v3/services`. An older server can serve both routes. Connection and authentication errors need investigation before they tell you anything about API support.

The following commands are for a server that returns `200` with a JSON `data` array from `/api/services`:

```sh
curl -fsS http://127.0.0.1:16686/api/services | jq '.data'
curl -fsSG http://127.0.0.1:16686/api/traces \
  --data-urlencode 'service=scout' \
  --data-urlencode 'tags={"incident.code":"slow-scan"}' \
  --data-urlencode 'limit=3' | jq '.data'
```

The older search requires `service`, accepts span tags in `tags`, and limits results with `limit`. With no explicit time range, it uses a two-day lookback. Its response contains `data` entries with `traceID`, `spans`, and `processes`, so a version 3 `jq` filter will not read it correctly.

A successful tag search identifies traces worth investigating. Read the matching span and its service identity before changing a workload, and retain the trace data if you need evidence of what the search found.

## Common pitfalls

> [!WARNING]
> - **Omitting the time bounds.** Version 3 trace searches require both bounds, including searches by attribute.
> - **Confusing no results with an unsupported route.** A version 3 search can return `404` when no traces match. Check the service endpoint, search values, and time window.
> - **Using the wrong response filter.** The older API returns `data`; version 3 returns `result.resourceSpans`.
> - **Assuming every service in a trace matched the attribute.** Inspect the matching span when a trace crosses services.
> - **Putting raw JSON in a URL.** Use `--data-urlencode` for the attribute object.

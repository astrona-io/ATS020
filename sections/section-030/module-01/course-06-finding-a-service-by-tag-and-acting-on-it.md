# Finding A Service By Tag And Acting On It

An incident report often gives you a clue, not a service name. It may say that requests with the code `slow-scan` are failing, and it is up to you to find which service is involved. Jaeger can answer this if the spans carry that code. A **tag** is a key-value pair on a span, and OpenTelemetry calls the same thing an **attribute**. This part searches for a tag in the web interface and through the API (application programming interface), changes the workloads that the search points to, and saves traces to a file as evidence.

## Send spans with distinct tags

You need spans with known tags to search for. Jaeger 2.22 serves its web interface and its API on port `16686` of the Service `jaeger`. Start a port-forward in a second terminal and leave it running:

<!-- astrona:playground:renew -->

```sh
kubectl -n observability port-forward svc/jaeger 16686:16686
```

In your first terminal, send test traces with `telemetrygen`, a tool that sends generated spans over OTLP (OpenTelemetry Protocol). The first run reports as the service `scout` and the second as `shuttle`, and each run puts a different `incident.code` tag on its spans. These runs send straight to Jaeger, because the goal here is test data and not a test of a pipeline:

```sh
kubectl -n observability run telemetrygen --restart=Never --rm -i --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.162.0 -- traces --otlp-insecure --otlp-endpoint jaeger.observability:4317 --service scout --traces 6 --telemetry-attributes incident.code=\"slow-scan\"
kubectl -n observability run telemetrygen --restart=Never --rm -i --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.162.0 -- traces --otlp-insecure --otlp-endpoint jaeger.observability:4317 --service shuttle --traces 6 --telemetry-attributes incident.code=\"queue-full\"
```

Each run prints its own log lines and exits. Allow a few seconds before you search, so that Jaeger has stored the spans.

## Search by tag in the web interface

Open `http://127.0.0.1:16686` in your browser and stay on the Search page. In the **Service** list, choose **All Services**, because you do not know the service yet. Jaeger 2.22 labels the tag field **Attributes**, and older versions label it **Tags**. Type the tag in the form `key=value`, as `incident.code=slow-scan`. If you need several tags, separate them with a space, and a trace must match all of them.

Select **Find Traces**. Each row in the results is one trace, and the row names the service. Look for `scout` in every row, then search for `incident.code=queue-full` and look for `shuttle`. The **Limit Results** field sets how many traces the page asks for.

## Search by tag through the API

The web interface is quick for one question. The API gives the same answer in a form that a script can use. Start by asking which services Jaeger knows. The list should include `scout` and `shuttle`:

```sh
curl -fsS http://127.0.0.1:16686/api/v3/services | jq -c .services
```

The route that searches traces is `/api/v3/traces`. Older guides and older Jaeger versions use the legacy `/api/traces?service=...` search form, which this release no longer serves. Older guides may also show parameter names such as `query.service_name`. This release still accepts those names, but marks them as deprecated, so use the names below.

The search needs a time range, given by `query.startTimeMin` and `query.startTimeMax`, in a form such as `2020-01-01T00:00:00Z`. Tags go in `query.attributes`, which holds a JSON (JavaScript Object Notation) object of keys and string values. `query.searchDepth` is the largest number of traces to return. This helper runs the search and prints the name of each service in the response. The option `--data-urlencode` makes the JSON safe to put in a URL, and `-G` sends the values as a `GET` query:

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

Look for `scout` from the first call and `shuttle` from the second. The service name is not on the span. It is on the **resource**, which describes what produced the spans, so the filter reads `resource.attributes`. Jaeger can search without a service name here because its in-memory storage allows it. A storage backend that does not allow it answers that it requires a service name.

## Act on the result

Now you know where to work. Suppose that `slow-scan` calls for a setting change on `scout`. Each service here has a Deployment with the same name. Change an environment variable on the Deployment and wait for the rollout. A change to the pod template makes Kubernetes replace the pod, so the new value is proved only when the new pod answers. The last command asks `scout` from the `shuttle` pod and prints the color that `podinfo` reports, which should be the new value:

```sh
kubectl -n starfleet set env deployment/scout PODINFO_UI_COLOR='#336699'
kubectl -n starfleet rollout status deployment/scout --timeout=120s
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout:9898/ | jq -r .color
```

Suppose that `queue-full` calls for more capacity on `shuttle`. Scale that Deployment and read its replica count. The `READY` column should show `2/2`. Then put both Deployments back as they were. A variable name with a trailing `-` removes the variable:

```sh
kubectl -n starfleet scale deployment shuttle --replicas=2
kubectl -n starfleet rollout status deployment/shuttle --timeout=120s
kubectl -n starfleet get deployment shuttle
kubectl -n starfleet scale deployment shuttle --replicas=1
kubectl -n starfleet set env deployment/scout PODINFO_UI_COLOR-
```

## Export an exact number of traces

Traces in this Jaeger live in memory and disappear when its pod restarts, so evidence for a report belongs in a file. To save three traces of `scout`, set the service with `query.serviceName`, set `query.searchDepth` to `3`, and redirect the response to the file. Jaeger returns the newest matching traces first and stops at that number:

```sh
curl -fsSG http://127.0.0.1:16686/api/v3/traces \
  --data-urlencode 'query.serviceName=scout' \
  --data-urlencode 'query.startTimeMin=2020-01-01T00:00:00Z' \
  --data-urlencode 'query.startTimeMax=2100-01-01T00:00:00Z' \
  --data-urlencode 'query.searchDepth=3' > /tmp/scout-traces.json
```

The response is one JSON document. Under `result.resourceSpans`, each entry has a `resource` and a list of `scopeSpans`, and each of those has a list of `spans`. Every span has a `traceId`. Jaeger adds the entries of all traces to one list, so one trace can fill more than one entry, and the length of `resourceSpans` is not the number of traces. Count the distinct trace IDs instead, and list the services in the file. The first command should print `3`, and the second should print only `scout`:

```sh
jq '[.result.resourceSpans[].scopeSpans[].spans[].traceId] | unique | length' /tmp/scout-traces.json
jq -r '[.result.resourceSpans[].resource.attributes[] | select(.key == "service.name") | .value.stringValue] | unique | .[]' /tmp/scout-traces.json
```

A tag search tells you where to look, and the search result is what justifies the change. Find the service first, change only what the search points to, and keep the traces in a file that shows what you found.

## Common pitfalls

> [!WARNING]
> Mistakes that waste time:
>
> - **Leaving out the time range.** Jaeger answers `400` with `min and max start time are required`. Both bounds are needed, even for a search by tag.
> - **Reading `404` as a broken API.** On `/api/v3/traces`, a `404` means that no trace matched. With `curl -f` you see only the error status, so check the spelling of the tag, the time range and the service.
> - **Counting `resourceSpans` entries.** They do not match traces one to one. Count distinct `traceId` values.
> - **Exporting from `/api/v3/trace-summaries`.** That route returns one summary for each trace and no spans, so the file has no span evidence.
> - **Writing the JSON by hand in a URL.** The quotes and braces in `query.attributes` must be URL-encoded. Let `--data-urlencode` do it.
> - **Restarting Jaeger before the export.** In-memory storage loses all traces when the pod restarts.

## Your mission: Find Tagged Traces And Remediate Deployments

You can now find a service by a span tag, change the Deployment behind it and save an exact number of traces as JSON. The mission gives you three workloads with distinct tags and an incident report that names only the tags, and asks you to change the two right Deployments and save five traces to a named file.

Pause the playground, then start the lab:

```sh
astrona stop ats-020-playground-030-01
```

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/labs/lab-02
```

The task is on the next page. When you have changed the Deployments and saved the file, grade your work:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-01/labs/lab-02
```

When the lab is done, remove it and start the playground again:

```sh
astrona destroy ats-020-lab-030-01-02
astrona start ats-020-playground-030-01
```

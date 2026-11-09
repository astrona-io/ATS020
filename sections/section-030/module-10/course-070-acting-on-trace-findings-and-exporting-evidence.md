# Acting on Trace Findings and Exporting Evidence

A trace search has identified `scout` for `incident.code=slow-scan` and `shuttle` for `incident.code=queue-full`. An incident task asks you to change a setting on `scout`, scale `shuttle`, and save three `scout` traces. The search identifies the workloads; the task defines the required changes.

Keep the Jaeger port-forward running at `http://127.0.0.1:16686`. The playground needs the tagged traces created by `telemetrygen`, and ongoing `scout` requests provide additional traces through the Collector.

## Change the named Deployments

In this playground, service names in traces match Kubernetes Deployment names. In other environments, confirm the mapping through resource attributes and workload configuration before editing anything.

<!-- astrona:playground:renew -->

Set `PODINFO_UI_COLOR` on `scout`, wait for the rollout, and request a response from the new application pod:

```sh
kubectl -n starfleet set env deployment/scout PODINFO_UI_COLOR='#336699'
kubectl -n starfleet rollout status deployment/scout --timeout=120s
kubectl -n starfleet exec deploy/shuttle -- curl -s http://scout:9898/ | jq -r .color
```

The response's `color` field should be `#336699`. Updating the environment changes the Deployment's pod template, which causes Kubernetes to replace its pods. The response verifies that the running application uses the setting.

For the scaling task, increase `shuttle` to two replicas and inspect readiness. The `READY` column should reach `2/2`. Then restore one replica and remove the temporary color setting:

```sh
kubectl -n starfleet scale deployment shuttle --replicas=2
kubectl -n starfleet rollout status deployment/shuttle --timeout=120s
kubectl -n starfleet get deployment shuttle
kubectl -n starfleet scale deployment shuttle --replicas=1
kubectl -n starfleet set env deployment/scout PODINFO_UI_COLOR-
```

A trailing `-` on an environment variable name removes it. These exercises demonstrate the requested changes; the generated incident tags alone do not establish that a color setting or extra replicas would fix a real performance problem.

## Save three traces

The playground stores Jaeger traces in memory, so a Jaeger pod restart removes them. Export evidence before restarting it. The version 3 application programming interface (API) returns trace data as JavaScript Object Notation (JSON).

Request up to three `scout` traces and write the response to `/tmp/scout-traces.json`:

```sh
curl -fsSG http://127.0.0.1:16686/api/v3/traces \
  --data-urlencode 'query.serviceName=scout' \
  --data-urlencode 'query.startTimeMin=2020-01-01T00:00:00Z' \
  --data-urlencode 'query.startTimeMax=2100-01-01T00:00:00Z' \
  --data-urlencode 'query.searchDepth=3' > /tmp/scout-traces.json
```

`query.serviceName` selects the service, the two time bounds define the search window, and `query.searchDepth=3` caps the result count. The `>` operator saves the response, replacing any existing file at that path. Check that `curl` succeeds before inspecting the file.

The response groups spans under `result.resourceSpans`, then `scopeSpans`, then `spans`. These groups describe resources and instrumentation scopes. Their count is not the trace count: one trace can span several groups, and each trace can contain several spans.

Count distinct `traceId` values, then list the service names represented in the file:

```sh
jq '[.result.resourceSpans[].scopeSpans[].spans[].traceId] | unique | length' /tmp/scout-traces.json
jq -r '[.result.resourceSpans[].resource.attributes[] | select(.key == "service.name") | .value.stringValue] | unique | .[]' /tmp/scout-traces.json
```

The first command should print `3`. A search limit is an upper bound, so fewer available matches can produce fewer traces. If the count is lower, allow more `scout` requests and repeat the export. The second command should print only `scout` for these playground traces; a trace involving several services can include additional service names.

The saved spans preserve what Jaeger returned and let you verify the requested count. Pair that evidence with the rollout and application checks to show both which workloads you selected and what changed.

## Common pitfalls

> [!WARNING]
> - **Treating a tag as a repair instruction.** Use the incident requirements and the span details to choose the change.
> - **Assuming a successful update reached the application.** Wait for rollout completion and check the resulting behavior.
> - **Counting resource groups or spans as traces.** Count distinct `traceId` values.
> - **Assuming the search limit guarantees enough results.** Check the file contains the exact number requested.
> - **Exporting trace summaries.** `/api/v3/trace-summaries` omits the full spans needed as evidence.

## Your mission: Find Tagged Traces and Remediate Deployments

You can now use trace attributes to select workloads, apply a requested change, and verify a trace export. The mission names incident tags instead of services; find the two relevant Deployments, change them as requested, and save five traces to the required file.

Pause the playground, then start the lab:

```sh
astrona stop ats-020-playground-030-01
```

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-10/labs/lab-02
```

When the Deployments and export are ready, grade your work:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-10/labs/lab-02
```

Remove the lab and restart the playground when you finish:

```sh
astrona destroy ats-020-lab-030-01-02
astrona start ats-020-playground-030-01
```

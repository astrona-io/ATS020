# Summary

The OpenTelemetry Operator manages Collectors from `OpenTelemetryCollector` resources. In the playground, cert-manager supplies the certificates that let the Kubernetes API server trust the Operator's admission webhooks. A ready Operator and a working webhook allow Collector resources to be checked and deployed.

The Collector receives spans, processes them, and exports them to Jaeger. Its trace pipeline activates the receivers, processors, and exporters it lists. OpenTelemetry Protocol (OTLP) uses port `4317` for gRPC and `4318` for HTTP by default. The application's transport, receiver port, and export destination must agree.

Collector mode determines placement. A Deployment provides a shared gateway, a DaemonSet places agents on eligible nodes, and sidecar mode injects a Collector into annotated application pods. Injection happens when a pod is created, and the application must use the sidecar's endpoint to send through it. Changing an existing Collector's mode requires replacing the resource.

A trace groups spans by a shared trace identifier. Parent identifiers connect operations, while context propagation carries that relationship across service requests. Jaeger's timeline shows where time was spent. A generated test trace checks delivery independently of the application's instrumentation.

Receiver ports and startup logs show what the Collector accepts. Exporter errors identify failed destinations, and increasing counters show spans entering and leaving the process. A recent trace retrieved from Jaeger confirms that the backend can return the delivered data. A running pod or an old service name in a search result cannot establish current delivery.

Attributes help find relevant spans and services. Jaeger 2.22 uses the version 3 query API with a required time range; older servers may also serve the legacy search routes. After checking the matching span and workload identity, apply the requested change and verify its effect. Export full traces when evidence is needed, and count distinct trace identifiers to check the requested total.

Span status records the result reported by instrumentation. `ERROR` marks a failure, while an `exception` event can provide its type, message, and stack trace. Recording an error and recording an exception are separate choices, so inspect the data the application supplies. Save the evidence before restarting in-memory storage, investigate the cause against the workload configuration, and verify recovery with spans created after the repair.

<!-- astrona:playground:destroy -->

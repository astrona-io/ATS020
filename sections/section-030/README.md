# Section 030: Distributed Tracing With OpenTelemetry And Jaeger

Makes the reader able to run an OpenTelemetry Collector with the OpenTelemetry Operator, send traces to Jaeger, and add tracing to an application without changing its code. It comes after metrics and logs because tracing reuses the Collector pipeline idea and answers the question metrics cannot — where in a chain of services the time went.

**Curriculum item covered:** Implementing Monitoring, Alerting, Logging, and Tracing Solutions

---

## What You Will Master

- Install the OpenTelemetry Operator after cert-manager and confirm its webhook is ready
- Write an OpenTelemetryCollector resource with an OTLP receiver, a batch processor and an exporter to Jaeger
- Choose the Collector mode (deployment, daemonset, sidecar) for a given need
- Send a test trace over OTLP and find it in the Jaeger UI and API
- Diagnose a broken pipeline from the Collector's logs (wrong endpoint, missing pipeline, unused receiver)
- Find a service by a span tag in the Jaeger UI and the `/api/v3` query API, recognise the legacy search routes on older servers, and act on the result by changing an environment variable and scaling a Deployment
- Export an exact number of traces for a service as JSON to a named file, and count them by distinct trace ID
- Write an Instrumentation resource with the exporter endpoint, propagators and sampler
- Annotate a Deployment so the operator injects the language agent, and restart it so the change takes effect
- Read the injected init container and environment variables to prove injection happened
- Follow one request across two services in Jaeger and name the slowest span
- Find why a pod was not instrumented (annotation on the wrong object, Instrumentation in another namespace, pod not restarted)

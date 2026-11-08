# Run An OpenTelemetry Collector With The Operator

Metrics tell you that something is slow. They do not tell you which step of a request took the time. A trace does: it records every step of one request, from the first service to the last, with a start time and a duration for each. Getting traces to a place where you can read them takes three components, and the exam expects you to build and repair that path by hand.

The three components are an instrumented application, an OpenTelemetry Collector and a trace backend. The application creates spans, the Collector receives, batches and forwards them, and Jaeger stores and shows them. On Kubernetes, the OpenTelemetry Operator runs the Collector for you from one custom resource, the OpenTelemetryCollector. When no trace arrives, the first question is which of the three stopped it.

The module has six parts. **The Operator And Its Webhook** installs the Operator after cert-manager and proves that its webhook answers. **A Collector With An OTLP Receiver And A Jaeger Exporter** writes the OpenTelemetryCollector for `scout` and shows what the Operator builds. **Reading A Trace In Jaeger** defines traces and spans and finds them with the API. **Choosing A Collector Mode** creates a gateway, an agent and a sidecar. **Diagnosing A Broken Collector Pipeline** fixes two faults and ends with a graded lab. **Finding A Service By Tag And Acting On It** searches Jaeger by a span tag, changes the Deployments that the search points to, saves traces to a file, finds the spans that ended with an error and their exception events, and ends with two graded labs.

## Learning objectives

After this module you can:

- Install the OpenTelemetry Operator after cert-manager and confirm that its webhook is ready.
- Write an OpenTelemetryCollector with an OTLP receiver, a batch processor and an exporter to Jaeger.
- Choose the Collector mode (deployment, daemonset or sidecar) for a given need.
- Send a test trace over OTLP and find it in the Jaeger API and web interface.
- Diagnose a broken pipeline from the Service ports, the Collector log and the Collector counters.
- Find a service by a span tag in the Jaeger web interface and API, detect whether an older server serves the legacy search routes, and change the Deployment behind it.
- Save an exact number of traces for a service as JSON, and count them by trace ID.
- Find the service whose spans carry the status `ERROR`, export their `exception` span events as JSON, and fix the cause the exception message names.

## Before you start

You need Kubernetes basics and `kubectl port-forward`, `kubectl logs` and `kubectl exec`, and `jq` on your machine. You need to read a Kubernetes Service and its ports.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. It has cert-manager 1.21.2 and Jaeger 2.22.0. The OpenTelemetry Operator (version 0.160.0) and the Collector (contrib image 0.162.0) are not installed yet: you install the Operator and create the Collector. No Prometheus stack runs, to save memory.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `observability` | `jaeger` | Jaeger 2.22.0 in one pod with in-memory storage. The Service `jaeger` has OTLP on ports `4317` and `4318` and the web interface and API on `16686` |
| `starfleet` | `scout` | One pod of `podinfo` 6.15.0 with OpenTelemetry tracing on. It sends spans over OTLP to `otel-collector.observability:4317`, a Service that does not exist yet |
| `starfleet` | `shuttle` | A client pod that sends a request to `scout` every 2 seconds, and a slow request (`/delay/1`) every tenth round |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

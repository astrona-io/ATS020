# Finding Why a Pod Is Not Instrumented

A `relay` pod can serve requests without having a tracing agent. A missing annotation or Instrumentation resource can leave the application running normally while its spans are absent from Jaeger. The pod's injected containers and settings give you a place to start investigating.

These exercises start with a working `nodejs` Instrumentation in `starfleet`, using `tracecontext` and `baggage`. The `relay` Deployment requests Node.js injection through its pod template. You will break that request, inspect the result, and restore it.

## Put the annotation on the wrong object

The Operator reads the injection annotation from the pod. A Deployment creates pods from `spec.template`, so an annotation on the Deployment's own metadata does not make those pods request injection.

<!-- astrona:playground:renew -->

Save this as `relay-misplaced-annotation.yaml`. It moves the annotation to the Deployment and removes it from the pod template:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-nodejs: "true"
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-nodejs: null
```

Apply the patch, wait for the rollout, and list the pods' init containers:

```sh
kubectl -n starfleet patch deployment relay --patch-file relay-misplaced-annotation.yaml
kubectl -n starfleet rollout status deployment/relay
kubectl -n starfleet get pods -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
```

Once the old pod has disappeared, the replacement has no injected init container:

```text
NAME                     INIT
relay-54b5786f9b-49w9f   <none>
```

Kubernetes accepts the annotation on the Deployment because it is valid metadata. Compare the two annotation locations:

```sh
kubectl -n starfleet get deployment relay -o json | jq -c '{deployment: .metadata.annotations["instrumentation.opentelemetry.io/inject-nodejs"], pod_template: .spec.template.metadata.annotations["instrumentation.opentelemetry.io/inject-nodejs"]}'
```

The result identifies the misplaced value:

```text
{"deployment":"true","pod_template":null}
```

The pod template has no injection request. In this case the Operator has no missing-resource error to report, because the pod did not ask for an Instrumentation. An empty error log does not establish that injection occurred.

## Request an Instrumentation that does not exist

Now restore the annotation on the template and remove the Instrumentation it would select. The value `"true"` selects from the pod's namespace. Save this as `relay-annotate-template.yaml`:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-nodejs: null
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-nodejs: "true"
```

Delete the Instrumentation first, then apply the patch and wait for the new pod:

```sh
kubectl -n starfleet delete instrumentation nodejs
kubectl -n starfleet patch deployment relay --patch-file relay-annotate-template.yaml
kubectl -n starfleet rollout status deployment/relay
```

The pod requests injection, but there is no Instrumentation in `starfleet`. Read the Operator log for the selection failure:

```sh
kubectl -n opentelemetry-operator-system logs deploy/opentelemetry-operator-controller-manager | grep "failed to select" | tail -1 | jq -c '{message, namespace, error}'
```

The relevant entry is:

```text
{"message":"failed to select an OpenTelemetry Instrumentation instance for this pod","namespace":"starfleet","error":"no OpenTelemetry Instrumentation instances available"}
```

This failure leaves the pod running without the agent. Other failures, such as an unavailable admission webhook, can prevent pod creation, so check Deployment events when no replacement pod appears.

If the intended Instrumentation exists in another namespace, use `<namespace>/<name>` as the annotation value, for example `observability/nodejs`. Use an explicit name to avoid ambiguous selection when a namespace contains several resources.

## Restore the settings and replace the pod

Recreate the Instrumentation in the pod's namespace. Save this as `instrumentation-nodejs.yaml`:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: nodejs
  namespace: starfleet
spec:
  exporter:
    endpoint: http://otel-collector.observability:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1"
```

Apply it:

```sh
kubectl apply -f instrumentation-nodejs.yaml
```

Inspect the running pod, restart the Deployment, and inspect the replacement:

```sh
kubectl -n starfleet get pods -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
kubectl -n starfleet rollout restart deployment/relay
kubectl -n starfleet rollout status deployment/relay
kubectl -n starfleet get pods -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
```

The first inspection still shows `<none>`. Recreating the resource cannot modify a running pod. After the rollout, the new pod should list `opentelemetry-auto-instrumentation-nodejs`; ignore any old pod still terminating.

Check the new pod's `NODE_OPTIONS`, exporter endpoint, and `OTEL_PROPAGATORS`. Then allow span export to settle and search Jaeger for a trace created after the repair. A `scout` span must have a `relay` span as its parent within the same trace.

## Choose the next check from the symptom

Use the observed state to decide whether to investigate admission, agent startup, export, or propagation:

| Observation | Next check |
| --- | --- |
| No replacement pod appears | Deployment events and admission-webhook availability |
| Pod has no injected init container | Pod-template annotation, selected Instrumentation, and Operator logs |
| Resource is fixed but the pod still has old settings | Pod creation time and rollout status |
| Agent is injected but no new `relay` spans arrive | Application logs, `NODE_OPTIONS`, exporter endpoint, and Collector reception |
| Both services export, but recent requests remain separate traces | `OTEL_PROPAGATORS` and parent identifiers in Jaeger |

The annotation, selected resource, and new pod must agree before the agent can run with the intended settings. A recent linked trace verifies the result beyond the Kubernetes configuration.

## Common pitfalls

> [!WARNING]
> - **Looking only at Deployment metadata.** Inspect the template and the resulting pod's annotations.
> - **Selecting the wrong namespace.** Use an explicit resource reference when the Instrumentation is elsewhere.
> - **Repairing settings without replacing the pod.** The running process keeps its original injected environment.
> - **Inspecting the terminating pod.** Wait for the rollout and identify the replacement.
> - **Stopping at a successful injection check.** Confirm new spans reach Jaeger and link across services.

## Your mission: Repair Missing Agent Injection

You can now diagnose a pod that runs without its tracing agent. Locate the injection faults, repair the annotation and resource selection, replace the pod, and confirm a new linked trace.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-030-02
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-20/labs/lab-01
```

Grade the completed tasks:

```sh
astrona submit -c sections/section-030/module-20/labs/lab-01
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-030-02
astrona start ats-020-playground-030-02
```

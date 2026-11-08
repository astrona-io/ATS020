# Finding Why A Pod Is Not Instrumented

Auto-instrumentation fails quietly. A pod that the Operator did not change still starts, still serves requests and shows no error. The only sign is a trace that is missing in Jaeger. This part breaks the setup in two ways on purpose, shows what each fault looks like in the cluster and in the Operator log, and gives a short order of checks that finds the cause.

The commands need the Instrumentation `nodejs` with the propagators `tracecontext` and `baggage` in `starfleet`, and a `relay` pod that carries the annotation `instrumentation.opentelemetry.io/inject-nodejs` on its pod template. That is the state in which the `relay` pod is instrumented.

## The annotation on the wrong object

The first fault is common. The annotation sits in the metadata of the Deployment, not in the metadata of its pod template. The webhook of the Operator only sees pods, and a pod gets its annotations from the template. Save this as `relay-misplaced-annotation.yaml`. It moves the annotation to the Deployment and removes it from the template:

<!-- astrona:playground:renew -->

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

Apply the patch and wait for the new pod. Then list the init containers of the pods:

```sh
kubectl -n starfleet patch deployment relay --patch-file relay-misplaced-annotation.yaml
kubectl -n starfleet rollout status deployment/relay
kubectl -n starfleet get pods -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
```

Wait a few seconds until only the new pod is listed. The new pod has no init container:

```text
NAME                     INIT
relay-54b5786f9b-49w9f   <none>
```

The Deployment accepted the annotation, so `kubectl` shows no error. Compare the two places:

```sh
kubectl -n starfleet get deployment relay -o json | jq -c '{deployment: .metadata.annotations["instrumentation.opentelemetry.io/inject-nodejs"], pod_template: .spec.template.metadata.annotations["instrumentation.opentelemetry.io/inject-nodejs"]}'
```

```text
{"deployment":"true","pod_template":null}
```

The output shows the fault: the value is on the Deployment and `null` on the pod template. The Operator log has no error for this case, because the webhook never saw an annotation. A pod without an init container and a log without errors points to the annotation.

## The Instrumentation that is not found

The second fault leaves the annotation in the right place and removes the Instrumentation the webhook looks for. With the value `"true"`, the webhook searches the namespace of the pod. Put the annotation back on the pod template and delete the Instrumentation. Save this as `relay-annotate-template.yaml`:

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

Apply it, delete the Instrumentation and wait for the new pod:

```sh
kubectl -n starfleet delete instrumentation nodejs
kubectl -n starfleet patch deployment relay --patch-file relay-annotate-template.yaml
kubectl -n starfleet rollout status deployment/relay
```

The pod is created with the right annotation, and it still gets no init container. This time the webhook did run, and it logged why it did nothing. Read the log of the Operator:

```sh
kubectl -n opentelemetry-operator-system logs deploy/opentelemetry-operator-controller-manager | grep "failed to select" | tail -1 | jq -c '{message, namespace, error}'
```

```text
{"message":"failed to select an OpenTelemetry Instrumentation instance for this pod","namespace":"starfleet","error":"no OpenTelemetry Instrumentation instances available"}
```

The log line names the namespace `starfleet` and says that no Instrumentation exists there. The pod is not blocked. The Operator lets it start without an agent. If the Instrumentation exists in another namespace, name it in the annotation as `<namespace>/<name>`, for example `observability/nodejs`.

Create the Instrumentation again. Save this as `instrumentation-nodejs.yaml`:

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

Apply it and look at the running pod. Then restart the Deployment and look again:

```sh
kubectl apply -f instrumentation-nodejs.yaml
kubectl -n starfleet get pods -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
kubectl -n starfleet rollout restart deployment/relay
kubectl -n starfleet rollout status deployment/relay
kubectl -n starfleet get pods -l app=relay -o 'custom-columns=NAME:.metadata.name,INIT:.spec.initContainers[*].name'
```

The running pod keeps showing `<none>` until the restart. After the restart, wait until only the new pod is listed. Its init container is `opentelemetry-auto-instrumentation-nodejs`. A trace with spans of `relay` appears in Jaeger about half a minute later.

## An order of checks

Four questions find the cause in this order. Each one has a command.

1. Does the pod have the init container `opentelemetry-auto-instrumentation-nodejs`? Use `kubectl get pods -o custom-columns` as above.
2. Is the annotation on the pod template, not only on the Deployment? Use the `jq` command above.
3. Does the Operator log say `failed to select an OpenTelemetry Instrumentation instance`? If yes, create the Instrumentation in the namespace of the pod, or name it in the annotation.
4. Was the pod created after the Instrumentation and the annotation existed? If not, restart the Deployment.

If the pod has the init container but a trace still does not join `relay` and `scout`, check the propagators in `OTEL_PROPAGATORS` of the pod. It must contain `tracecontext`.

You can now tell why a pod got no agent from three signs: the init container, the place of the annotation and the Operator log. The mission below puts a broken setup in front of you and asks you to find and fix it.

## Your mission: Get Two Services Into One Trace

You can now find why the Operator leaves a pod without an agent, and what stops two services from sharing one trace. The mission starts a cluster in which `relay` is set up for auto-instrumentation but Jaeger shows no span from it. You find the faults, fix them and prove the fix with one trace that has spans from both services.

Pause the playground first, so that only one cluster runs:

```sh
astrona stop ats-020-playground-030-02
```

Start the lab, and read the task:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-030/module-20/labs/lab-01
```

When you finish, submit your work for grading:

```sh
astrona submit -c sections/section-030/module-20/labs/lab-01
```

After the grader passes, remove the lab and start the playground again:

```sh
astrona destroy ats-020-lab-030-02
astrona start ats-020-playground-030-02
```

## Common pitfalls

> [!WARNING]
> - **Putting the annotation in the metadata of the Deployment.** It belongs in `spec.template.metadata.annotations`. The Operator log stays silent in this case.
> - **Creating the Instrumentation in another namespace.** The value `"true"` searches the namespace of the pod. Use `<namespace>/<name>` for a different namespace.
> - **Checking the old pod.** A fix reaches only pods created afterwards. Restart the Deployment and check the new pod.
> - **Using `kubectl get pods` after a restart without waiting.** The old pod is listed as `Terminating` for a short time.

# The Operator And Its Webhook

A Collector is a program that receives telemetry, changes it and sends it on. On Kubernetes you could write its Deployment, ConfigMap and Services by hand. The OpenTelemetry Operator does that work for you from one resource. This part installs the Operator and proves that it works before you give it anything to run.

## What the Operator needs

The **OpenTelemetry Operator** is a controller that runs in the cluster and watches custom resources of the group `opentelemetry.io`. The one this module uses is the **OpenTelemetryCollector**. When you create one, the Operator creates the Deployment (or DaemonSet), the ConfigMap with the Collector configuration and the Services.

The Operator also runs an admission webhook. A **webhook** is an HTTPS service that the Kubernetes API server calls before it stores an object. The Operator uses a **mutating webhook** to add defaults and to inject sidecar containers, and a **validating webhook** to reject a bad OpenTelemetryCollector. The API server only talks to a webhook over TLS, so the webhook needs a certificate that the API server trusts.

**cert-manager** supplies that certificate. It is a controller that creates and renews certificates from `Issuer` and `Certificate` resources. The Operator's installation file contains a `Certificate` and an `Issuer`, so cert-manager must run first. In the playground it already does.

## Install the Operator

Check that the three cert-manager Deployments are running:

<!-- astrona:playground:renew -->

```sh
kubectl -n cert-manager get pods
```

You should see:

```text
NAME                                     READY   STATUS    RESTARTS   AGE
cert-manager-7dd5fd898d-cql8p            1/1     Running   0          2m1s
cert-manager-cainjector-f555478d-4g8td   1/1     Running   0          2m1s
cert-manager-webhook-69d4696bcf-gwxsv    1/1     Running   0          2m1s
```

The Operator project publishes one YAML file per release. Apply the file for version 0.160.0. The `--server-side` flag lets the API server do the merge, which avoids the size limit that `kubectl apply` meets with large custom resource definitions:

```sh
kubectl apply --server-side -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.160.0/opentelemetry-operator.yaml
```

The file creates many objects, so the output is long. These are the last lines:

```text
deployment.apps/opentelemetry-operator-controller-manager serverside-applied
certificate.cert-manager.io/opentelemetry-operator-serving-cert serverside-applied
issuer.cert-manager.io/opentelemetry-operator-selfsigned-issuer serverside-applied
mutatingwebhookconfiguration.admissionregistration.k8s.io/opentelemetry-operator-mutating-webhook-configuration serverside-applied
validatingwebhookconfiguration.admissionregistration.k8s.io/opentelemetry-operator-validating-webhook-configuration serverside-applied
```

The Operator itself runs as one Deployment in the namespace `opentelemetry-operator-system`. Wait until it is available:

```sh
kubectl -n opentelemetry-operator-system rollout status deploy/opentelemetry-operator-controller-manager --timeout=180s
```

```text
deployment "opentelemetry-operator-controller-manager" successfully rolled out
```

## Confirm that the webhook is ready

A running pod does not prove that the webhook works. The webhook is ready when cert-manager has issued its certificate and the API server has the certificate authority (CA) to trust it. Check the `Certificate` first:

```sh
kubectl -n opentelemetry-operator-system get certificate,issuer
```

```text
NAME                                                              READY   SECRET                                                   AGE
certificate.cert-manager.io/opentelemetry-operator-serving-cert   True    opentelemetry-operator-controller-manager-service-cert   22s

NAME                                                              READY   AGE
issuer.cert-manager.io/opentelemetry-operator-selfsigned-issuer   True    22s
```

Both are `READY True`. The Secret named in the output holds the certificate and its private key, and the Operator pod mounts it. The cert-manager `cainjector` copies the CA into the `caBundle` field of the webhook configurations, which is how the API server learns to trust the webhook.

The strongest proof is a request that only the webhook can reject. Save this as `collector-invalid.yaml`. It uses a `mode` that does not exist:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel
  namespace: observability
spec:
  mode: foo
  config:
    receivers:
      otlp:
        protocols:
          grpc: {}
    exporters:
      debug: {}
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [debug]
```

Ask the API server to check it without storing it:

```sh
kubectl apply --dry-run=server -f collector-invalid.yaml
```

```text
The OpenTelemetryCollector "otel" is invalid: 
* spec.mode: Unsupported value: "foo": supported values: "daemonset", "deployment", "sidecar", "statefulset"
* <nil>: Invalid value: null: some validation rules were not checked because the object was invalid; correct the existing errors to complete validation
```

The API server called the Operator's validating webhook, and the webhook answered with an error. The message also lists the four modes the next parts use. List the custom resources the Operator added:

```sh
kubectl api-resources --api-group=opentelemetry.io
```

```text
NAME                      SHORTNAMES           APIVERSION                  NAMESPACED   KIND
instrumentations          otelinst,otelinsts   opentelemetry.io/v1alpha1   true         Instrumentation
opampbridges                                   opentelemetry.io/v1alpha1   true         OpAMPBridge
opentelemetrycollectors   otelcol,otelcols     opentelemetry.io/v1beta1    true         OpenTelemetryCollector
targetallocators                               opentelemetry.io/v1alpha1   true         TargetAllocator
```

You can now install the Operator after cert-manager and prove that its webhook answers. The resource you will use is `opentelemetrycollectors`, shortened to `otelcol`. The open question is what to put in it, so that spans from `scout` reach Jaeger.

## Common pitfalls

> [!WARNING]
> - **Installing the Operator before cert-manager.** The installation file contains a `Certificate` and an `Issuer`. The API server rejects them while cert-manager's custom resource definitions do not exist.
> - **Creating a Collector right after the install.** The webhook can need a few seconds after the pod is `Running`. If the first `kubectl apply` fails with an error that names a webhook, wait a few seconds and run it again.
> - **Checking only that the Operator pod runs.** The pod can run while the certificate is not ready. Check `get certificate`, or test with `--dry-run=server`.

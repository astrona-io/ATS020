---
title: "The Operator And Its Webhook"
maturity: published
reviewed: "2026-11-08"
---

# The Operator and Its Webhook

The OpenTelemetry Collector receives, processes, and exports telemetry data. On Kubernetes, the OpenTelemetry Operator manages the Collector's Deployment, configuration, and Services from an `OpenTelemetryCollector` custom resource.

The playground already runs the Operator. This part checks that the Operator runs and that its admission webhook is ready, because a Collector can only be created when both are true.

## What the Operator Needs

The **OpenTelemetry Operator** runs in your cluster and watches custom resources in the `opentelemetry.io` API group. This module uses the `OpenTelemetryCollector` resource. When you create one, the Operator creates and manages the Collector workload, its configuration ConfigMap, and its Services.

The Operator also provides **admission webhooks**: HTTPS endpoints that the Kubernetes API server calls before accepting a resource.

- **Mutating webhooks** apply defaults and inject containers into eligible pods, including Collector sidecars.
- **Validating webhooks** check resources such as `OpenTelemetryCollector` and reject invalid configurations.

These endpoints require TLS certificates trusted by the Kubernetes API server.

**cert-manager** provisions and renews the webhook certificate using `Issuer` and `Certificate` resources included in the Operator installation manifest. It must be running before the Operator is installed. The playground installed cert-manager 1.21.3 first, then the Operator 0.162.0 from its release manifest (`opentelemetry-operator.yaml`) with `kubectl apply --server-side`.

<!-- astrona:playground:renew -->

## Check the Operator

Check that the three cert-manager components are running:

```sh
kubectl -n cert-manager get pods
```

Expected output:

```text
NAME                                     READY   STATUS    RESTARTS   AGE
cert-manager-7dd5fd898d-6q8jh            1/1     Running   0          10m
cert-manager-cainjector-f555478d-fl5d8   1/1     Running   0          10m
cert-manager-webhook-69d4696bcf-wgc9d    1/1     Running   0          10m
```

Pod names and ages will vary.

The release manifest puts the Operator in the namespace `opentelemetry-operator-system`. It runs as one Deployment, `opentelemetry-operator-controller-manager`. Check the Deployment and its pod:

```sh
kubectl -n opentelemetry-operator-system get deployment,pods
```

Expected output:

```text
NAME                                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/opentelemetry-operator-controller-manager   1/1     1            1           10m

NAME                                                            READY   STATUS    RESTARTS   AGE
pod/opentelemetry-operator-controller-manager-d6b7699d5-lhn69   1/1     Running   0          10m
```

The manifest also created the custom resource definitions, the certificate, the issuer and the two webhook configurations. The webhook configurations are cluster-wide objects, so they have no namespace. List them:

```sh
kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration | grep opentelemetry
```

Expected output:

```text
validatingwebhookconfiguration.admissionregistration.k8s.io/opentelemetry-operator-validating-webhook-configuration   8          10m
mutatingwebhookconfiguration.admissionregistration.k8s.io/opentelemetry-operator-mutating-webhook-configuration   5          10m
```

The number is the count of webhooks in each configuration. Each one is a rule that sends a kind of resource, such as an `OpenTelemetryCollector` or a pod, to the Operator before the API server stores it.

## Check the Webhook Certificate

A running Operator pod alone does not prove that the API server can call its webhook. The webhook also needs a valid TLS certificate and a trusted certificate authority (CA).

Check the certificate and issuer:

```sh
kubectl -n opentelemetry-operator-system get certificate,issuer
```

Expected output:

```text
NAME                                                              READY   SECRET                                                   AGE
certificate.cert-manager.io/opentelemetry-operator-serving-cert   True    opentelemetry-operator-controller-manager-service-cert   10m

NAME                                                              READY   AGE
issuer.cert-manager.io/opentelemetry-operator-selfsigned-issuer   True    10m
```

Both resources should report `READY True`.

The Secret contains the webhook certificate and private key, which the Operator pod mounts. The cert-manager `cainjector` adds the CA certificate to the webhook configurations' `caBundle` fields so the API server can verify the webhook's certificate.

## Test Resource Validation

Save the following manifest as `collector-invalid.yaml`. It deliberately uses the unsupported mode `foo`:

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

Submit it for server-side validation without creating the resource:

```sh
kubectl apply --dry-run=server -f collector-invalid.yaml
```

The request should fail with an error similar to:

```text
The OpenTelemetryCollector "otel" is invalid:
* spec.mode: Unsupported value: "foo": supported values: "daemonset", "deployment", "sidecar", "statefulset"
* <nil>: Invalid value: null: some validation rules were not checked because the object was invalid; correct the existing errors to complete validation
```

This confirms that unsupported modes are rejected. However, the CRD schema can reject this value before the validating webhook runs, so this error alone does not prove that the webhook answered.

Change `mode: foo` to `mode: deployment` and repeat the dry run:

```sh
kubectl apply --dry-run=server -f collector-invalid.yaml
```

The output is `opentelemetrycollector.opentelemetry.io/otel created (server dry run)`. A successful dry run confirms that the corrected resource passes admission without being stored. Errors mentioning a failed webhook call, an untrusted certificate, or missing endpoints indicate that webhook readiness needs further investigation.

## Inspect the Available Resources

List the custom resources registered by the Operator:

```sh
kubectl api-resources --api-group=opentelemetry.io
```

Expected output:

```text
NAME                      SHORTNAMES           APIVERSION                  NAMESPACED   KIND
instrumentations          otelinst,otelinsts   opentelemetry.io/v1alpha1   true         Instrumentation
opampbridges                                   opentelemetry.io/v1alpha1   true         OpAMPBridge
opentelemetrycollectors   otelcol,otelcols     opentelemetry.io/v1beta1    true         OpenTelemetryCollector
targetallocators                               opentelemetry.io/v1alpha1   true         TargetAllocator
```

The next section uses `OpenTelemetryCollector`, also available through the short name `otelcol`, to configure the pipeline that forwards spans from `scout` to Jaeger.

## Common Pitfalls

> [!WARNING]
> - **Looking for the Operator in the wrong namespace.** The release manifest installs it in `opentelemetry-operator-system`, not in the namespace of your Collector. Its logs and its certificate are there too.
> - **Missing that cert-manager is down.** The Operator manifest includes `Certificate` and `Issuer` resources. If cert-manager does not run, the certificate is not issued or renewed, and the webhook fails even though the Operator pod is `Running`.
> - **Creating a Collector right after the Operator pod restarts.** The webhook may need a few seconds to become available again. If `kubectl apply` reports a webhook connection error, wait briefly and retry. If the error persists, inspect the webhook Service, endpoints, and certificate.
> - **Assuming a running pod means the webhook is ready.** Check that the webhook certificate reports `READY True`, then submit a valid Collector manifest using `kubectl apply --dry-run=server` to check admission without creating the resource.

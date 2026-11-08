---
title: "The Operator And Its Webhook"
maturity: published
reviewed: "2026-11-08"
---

# The Operator and Its Webhook

The OpenTelemetry Collector receives, processes, and exports telemetry data. On Kubernetes, the OpenTelemetry Operator manages the Collector's Deployment, configuration, and Services from an `OpenTelemetryCollector` custom resource.

In this section, you will install the Operator and verify that its admission webhook is ready before creating a Collector.

## What the Operator Needs

The **OpenTelemetry Operator** runs in your cluster and watches custom resources in the `opentelemetry.io` API group. This module uses the `OpenTelemetryCollector` resource. When you create one, the Operator creates and manages the Collector workload, its configuration ConfigMap, and its Services.

The Operator also provides **admission webhooks**: HTTPS endpoints that the Kubernetes API server calls before accepting a resource.

- **Mutating webhooks** apply defaults and inject containers into eligible pods, including Collector sidecars.
- **Validating webhooks** check resources such as `OpenTelemetryCollector` and reject invalid configurations.

These endpoints require TLS certificates trusted by the Kubernetes API server.

**cert-manager** provisions and renews the webhook certificate using `Issuer` and `Certificate` resources included in the Operator installation manifest. It must be running before you install the Operator. In this playground, cert-manager is already installed.

<!-- astrona:playground:renew -->

## Install the Operator

Check that the three cert-manager components are running:

```sh
kubectl -n cert-manager get pods
```

Expected output:

```text
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-7dd5fd898d-cql8p               1/1     Running   0          2m1s
cert-manager-cainjector-f555478d-4g8td       1/1     Running   0          2m1s
cert-manager-webhook-69d4696bcf-gwxsv       1/1     Running   0          2m1s
```

Pod names and ages will vary.

Install OpenTelemetry Operator **0.160.0** using its release manifest:

```sh
kubectl apply --server-side -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.160.0/opentelemetry-operator.yaml
```

The `--server-side` flag delegates apply operations to the API server and avoids the large annotation that client-side apply adds to CustomResourceDefinitions.

The manifest creates the Operator, custom resource definitions, certificates, and webhook configurations. The final lines should resemble:

```text
deployment.apps/opentelemetry-operator-controller-manager serverside-applied
certificate.cert-manager.io/opentelemetry-operator-serving-cert serverside-applied
issuer.cert-manager.io/opentelemetry-operator-selfsigned-issuer serverside-applied
mutatingwebhookconfiguration.admissionregistration.k8s.io/opentelemetry-operator-mutating-webhook-configuration serverside-applied
validatingwebhookconfiguration.admissionregistration.k8s.io/opentelemetry-operator-validating-webhook-configuration serverside-applied
```

Wait for the Operator Deployment to become available:

```sh
kubectl -n opentelemetry-operator-system rollout status \
  deployment/opentelemetry-operator-controller-manager \
  --timeout=180s
```

Expected output:

```text
deployment "opentelemetry-operator-controller-manager" successfully rolled out
```

## Check the Webhook Certificate

A running Operator pod alone does not prove that the API server can call its webhook. The webhook also needs a valid TLS certificate and a trusted certificate authority (CA).

Check the certificate and issuer:

```sh
kubectl -n opentelemetry-operator-system get certificate,issuer
```

Expected output:

```text
NAME                                                              READY   SECRET                                                   AGE
certificate.cert-manager.io/opentelemetry-operator-serving-cert     True    opentelemetry-operator-controller-manager-service-cert   22s

NAME                                                              READY   AGE
issuer.cert-manager.io/opentelemetry-operator-selfsigned-issuer     True    22s
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
```

This confirms that unsupported modes are rejected. However, the CRD schema can reject this value before the validating webhook runs, so this error alone does not prove that the webhook answered.

Change `mode: foo` to `mode: deployment` and repeat the dry run:

```sh
kubectl apply --dry-run=server -f collector-invalid.yaml
```

A successful dry run confirms that the corrected resource passes admission without being stored. Errors mentioning a failed webhook call, an untrusted certificate, or missing endpoints indicate that webhook readiness needs further investigation.

## Inspect the Available Resources

List the custom resources registered by the Operator:

```sh
kubectl api-resources --api-group=opentelemetry.io
```

Expected output:

```text
NAME                     SHORTNAMES          APIVERSION                  NAMESPACED   KIND
instrumentations         otelinst,otelinsts   opentelemetry.io/v1alpha1   true         Instrumentation
opampbridges                                 opentelemetry.io/v1alpha1   true         OpAMPBridge
opentelemetrycollectors   otelcol,otelcols    opentelemetry.io/v1beta1    true         OpenTelemetryCollector
targetallocators                             opentelemetry.io/v1alpha1   true         TargetAllocator
```

The next section uses `OpenTelemetryCollector`, also available through the short name `otelcol`, to configure the pipeline that forwards spans from `scout` to Jaeger.

## Common Pitfalls

> [!WARNING]
> - **Installing the Operator before cert-manager is ready.** The Operator manifest includes `Certificate` and `Issuer` resources. Install cert-manager and wait for its components to become ready before applying the Operator manifest.
> - **Creating a Collector immediately after installation.** The webhook may need additional time to become available after the Operator pod starts. If `kubectl apply` reports a webhook connection error, wait briefly and retry. If the error persists, inspect the webhook Service, endpoints, and certificate.
> - **Assuming a running pod means the webhook is ready.** Check that the webhook certificate reports `READY True`, then submit a valid Collector manifest using `kubectl apply --dry-run=server` to check admission without creating the resource.

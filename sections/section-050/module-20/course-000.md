# Diagnose And Fix Broken Platform Components

A broken workload shows its failure in its own pod. A broken platform component shows its failure somewhere else. A `kubectl create` fails with an error about a webhook you never touched. A new rule is accepted by the API server and never appears in Prometheus. On the exam these faults cost the most time, because the symptom does not point at the component that caused it.

This module teaches how to follow a platform symptom back to the component that produces it. You read the error text, name the component that should have done the work, read the object that component owns, and fix the cause without removing the safety it provides. You then prove the fix with the behaviour that was lost, such as a create that works or a Prometheus target that reports `1`.

The module has four parts. **A Webhook Service Without Endpoints** follows an admission webhook error from the API server to a Service that no pod matches. **An Expired Webhook Certificate** reads an `x509` error, checks a certificate with `openssl` and signs a new one. **A Controller Scaled To Zero** finds a stopped Prometheus Operator and ends with a graded lab on all three faults. **A GitOps Application Out Of Sync Or Degraded** reads the sync and health status of an Argo CD Application and finds a bad path, a bad revision, a failing hook and a degraded child resource.

## Learning objectives

After this module you can:

- Read the error text of a failing admission webhook and name the webhook, the Service and the reason.
- Fix a webhook Service that has no endpoints by comparing its selector with the pod labels, without deleting the webhook or setting `failurePolicy: Ignore`.
- Find an expired serving certificate from the `x509` error and `openssl`, sign a new one with the platform CA and restart the webhook server.
- Find a controller that does not run from its Deployment and events, and explain why the status of its resources can still look healthy.
- Read the sync status and the health status of an Argo CD Application, and find with `argocd app diff` and `kubectl describe application` why it is `OutOfSync` or `Degraded`.
- Fix a bad source path, a bad `targetRevision`, a failing hook or a degraded child resource in Git, not on the live object.
- Prove each fix with the behaviour it restores: a create that works, a webhook log line, a target with `up == 1`, a rule loaded in Prometheus.

## Before you start

You need to know what a Deployment, a Service and a Secret are, and the commands `kubectl get`, `kubectl describe`, `kubectl logs` and `kubectl exec`. You need `openssl` on your machine. You need to know what a Prometheus target and an alerting rule are. The last part also uses the idea of GitOps: a Git repository holds the manifests, and a controller applies them to the cluster.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. A trimmed Prometheus stack is installed in `monitoring`: the Prometheus Operator and one Prometheus. No Alertmanager and no Grafana run, to save memory. The cluster starts broken on purpose, and you fix it step by step in the parts.

| Object | What it is | What is wrong |
| --- | --- | --- |
| `starfleet-policy` | A webhook server in `webhook-system` that checks every create of a Deployment in `starfleet` | Its Service has no endpoints, so every create in `starfleet` fails |
| `outpost-policy` | The same webhook for the namespace `outpost` | Its serving certificate expired, so every create in `outpost` fails |
| `kps-operator` | The Prometheus Operator in `monitoring` | It is scaled to zero, so the ServiceMonitor and PrometheusRule for `scout` never reach Prometheus |
| `shuttle`, `drifter` | Client pods with `curl` in `starfleet` and `outpost` | Nothing. You send test requests from them |
| `scout` | `podinfo` 6.15.0, port `9898` | Nothing. It is the workload that Prometheus should scrape |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

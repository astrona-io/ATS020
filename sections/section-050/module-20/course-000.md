# Diagnose And Fix Broken Platform Components

Work through one practical outcome at a time. Each graded lab follows the lesson that prepares it and starts from its own cluster state. The 4 labs each have 3–5 tasks, with 10–15 minutes of task work plus startup and telemetry delays.

## Learning sequence

| Lesson | Practice after reading |
| --- | --- |
| A Webhook Service Without Endpoints | Repair A Webhook Service Port |
| An Expired Webhook Certificate | Renew An Expired Webhook Certificate |
| A Controller Scaled To Zero | Restore The Prometheus Operator |
| Recover A GitOps Source Path | Recover A GitOps Source Path |

## What you will prove

- Repair A Webhook Service Port.
- Renew An Expired Webhook Certificate.
- Restore The Prometheus Operator.
- Recover A GitOps Source Path.

## Before you start

You need to know what a Deployment, a Service and a Secret are, and the commands `kubectl get`, `kubectl describe`, `kubectl logs` and `kubectl exec`. You need `openssl` on your machine. You need to know what a Prometheus target and an alerting rule are. The last part also uses the idea of GitOps: a Git repository holds the manifests, and a controller applies them to the cluster.

Your playground is a single-node `kind` cluster running Kubernetes 1.35. A trimmed Prometheus stack is installed in `monitoring`: the Prometheus Operator and one Prometheus. No Alertmanager and no Grafana run, to save memory. The cluster starts broken on purpose, and you fix it step by step in the parts.

| Object | What it is | What is wrong |
| --- | --- | --- |
| `starfleet-policy` | A webhook server in `webhook-system` that checks every create of a Deployment in `starfleet` | Its Service has no endpoints, so every create in `starfleet` fails |
| `outpost-policy` | The same webhook for the namespace `outpost` | Its serving certificate expired, so every create in `outpost` fails |
| `kps-operator` | The Prometheus Operator in `monitoring` | It is scaled to zero, so the ServiceMonitor and PrometheusRule for `scout` never reach Prometheus |
| `shuttle`, `drifter` | Client pods with `curl` in `starfleet` and `outpost` | Nothing. You send test requests from them |
| `scout` | `podinfo` 6.17.0, port `9898` | Nothing. It is the workload that Prometheus should scrape |

Launch the playground for the reading exercises:

<!-- astrona:playground -->

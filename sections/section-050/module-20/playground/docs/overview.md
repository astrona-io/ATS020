# Overview: Diagnose And Fix Broken Platform Components (Playground)

This playground gives you a cluster in which three parts of the platform are broken on purpose. Two admission webhooks reject every create of a Deployment, and the Prometheus Operator is stopped. You find each cause with `kubectl`, fix it, and prove the fix with a request, a pod or a Prometheus query. There is no grading.

## What's in the box

The cluster runs Kubernetes 1.35.8 on one node. A trimmed kube-prometheus-stack 93.3.0 is installed in the namespace `monitoring`: the Prometheus Operator and one Prometheus. Alertmanager, Grafana, node-exporter and kube-state-metrics are not installed. The bootstrap changes no fault: every fault is still there when you get the terminal.

| Object | Namespace | What it is |
| --- | --- | --- |
| `shuttle` | `starfleet` | A healthy client pod with `curl`. You send requests with `kubectl exec deploy/shuttle -- curl ...` |
| `scout` | `starfleet` | `podinfo` 6.17.0 on port `9898`, with a Service, a ServiceMonitor and a PrometheusRule named `scout-alerts` |
| `drifter` | `outpost` | A healthy client pod with `curl` |
| `starfleet-policy` | `webhook-system` | A webhook server (Deployment and Service). A ValidatingWebhookConfiguration of the same name sends every create of a Deployment in `starfleet` to it |
| `outpost-policy` | `webhook-system` | The same for the namespace `outpost` |
| `webhook-ca` | `webhook-system` | A Secret with the certificate authority (CA) that signed the serving certificates of both webhook servers |
| `kps-operator` | `monitoring` | The Prometheus Operator Deployment |

Both webhooks use `failurePolicy: Fail`. The server of each webhook allows every request. The faults are in how the API server reaches the server, not in the policy.

## The three faults

| Fault | Where you see it |
| --- | --- |
| The Service `starfleet-policy` has no endpoints | Creating a Deployment in `starfleet` fails with `connection refused` |
| The serving certificate of `outpost-policy` expired | Creating a Deployment in `outpost` fails with an `x509` error |
| The Prometheus Operator is scaled to zero | `up{job="scout"}` has no series and the rule `ScoutDown` is not loaded in Prometheus |

## Helpers

This helper creates a Deployment in a namespace and prints the answer of the API server. It deletes the Deployment again when the create works:

```sh
try_create() {
  kubectl -n "$1" create deployment try-create --image=ghcr.io/stefanprodan/podinfo:6.17.0 \
    && kubectl -n "$1" delete deployment try-create
}
```

For example, `try_create starfleet`.

This helper asks Prometheus a query from `shuttle` and prints the JSON answer:

```sh
prom_query() {
  kubectl -n starfleet exec deploy/shuttle -- curl -s -G http://kps-prometheus.monitoring:9090/api/v1/query --data-urlencode "query=$1"
}
```

For example, `prom_query 'up{job="scout"}'`.

## Practice tasks

- Create a Deployment in `starfleet` and in `outpost`. Read the two error messages and write down which component each one names.
- Find the Service and the pods behind the webhook `starfleet-policy`. Compare the selector of the Service with the labels of the pods, and fix the Service.
- Read the serving certificate of `outpost-policy` with `openssl`. Sign a new one with the CA in `webhook-ca`, store it in the Secret `outpost-policy-tls`, and restart the webhook server.
- Prove both webhook fixes by creating a Deployment and by reading the log of the webhook server.
- Find why `up{job="scout"}` has no series. Bring the Prometheus Operator back and wait for the target to report `1`.
- Check that the rule `ScoutDown` is loaded in Prometheus.

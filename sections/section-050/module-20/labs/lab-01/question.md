# Question

Solve this question on: `terminal`

The platform in this cluster is broken. Two admission webhooks check every create of a Deployment: `starfleet-policy` for the namespace `starfleet` and `outpost-policy` for the namespace `outpost`. Both run in the namespace `webhook-system`, each with a Deployment and a Service of the same name. The Prometheus Operator runs in `monitoring` as the Deployment `kps-operator`. The `shuttle` pod in `starfleet` is healthy and sends test requests with `kubectl exec deploy/shuttle -- curl ...`.

The `drifter` in `outpost` and the `scout` in `starfleet` must keep working. Teams cannot deploy to either namespace, and nobody sees `scout` in Prometheus. You must find and fix three causes.

## Task

1. Find out why a create of a Deployment in `starfleet` fails. Fix the cause so that the create works and the webhook server `starfleet-policy` answers the request.
2. Find out why a create of a Deployment in `outpost` fails. Fix the cause so that the create works and the webhook server `outpost-policy` answers the request.
3. Find out why Prometheus does not scrape `scout` and does not know the alerting rule `ScoutDown`. Fix the cause so that the query `up{job="scout"}` returns `1` and the rule `ScoutDown` is loaded in Prometheus.

## Constraints

- Keep both `ValidatingWebhookConfiguration` objects. Both keep `failurePolicy: Fail`, keep calling their own Service and keep matching Deployments. Do not delete a webhook configuration and do not set `failurePolicy: Ignore`.
- Keep the Deployments and Services of both webhook servers, the ServiceMonitor `scout` and the PrometheusRule `scout-alerts`. Do not delete them.
- The CA that both webhook configurations trust is in the Secret `webhook-ca` in `webhook-system`. Do not change the `caBundle` of a webhook configuration.
- Do not install a second Prometheus.

## How the answer is checked

The grader runs four checks. The first two create a real Deployment in `starfleet` and in `outpost`, and check that the webhook server logged a new request. The third reads `up{job="scout"}` and the loaded rules from the Prometheus API. The fourth checks that both webhook configurations, the webhook servers, the workloads, the ServiceMonitor, the PrometheusRule and the operator Deployment are still in place. The grader waits and retries for a few minutes, because endpoints and Prometheus update late.

Hint: start with the error text of `kubectl -n starfleet create deployment test --image=ghcr.io/stefanprodan/podinfo:6.17.0`. It names the webhook, the Service and the reason.

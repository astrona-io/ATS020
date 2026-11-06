# Diagnose Alert Evaluation And Delivery

The `scout` target can be healthy while an alert about it is still pending. A **pending alert** has met its condition but has not met its waiting time. To diagnose a missing notification, first prove that Prometheus loaded and evaluated the rule, then check whether Alertmanager received it. Each component has its own state.

<!-- astrona:playground:renew -->

Save this as `prometheusrule-scout-evaluation.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-evaluation
  namespace: starfleet
  labels:
    release: kps
spec:
  groups:
    - name: scout-evaluation
      interval: 15s
      rules:
        - alert: ScoutEvaluationCheck
          expr: up{namespace="starfleet",job="scout"} == 1
          for: 1m
          labels:
            team: scout
            severity: warning
```

This diagnostic rule alerts on a healthy target so you can follow the states without causing an outage. `up` is the scrape result: `1` means the last scrape succeeded. The comparison keeps each healthy target's series, so two targets produce two alert instances. The rule adds `team` and `severity` labels to each instance.

Apply it:

```sh
kubectl apply -f prometheusrule-scout-evaluation.yaml
```

Then check the result through the Kubernetes Service proxy. The **application programming interface (API)** returns structured data that you can inspect with `jq`, a command that reads JavaScript Object Notation (JSON):

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/rules' | jq '.data.groups[] | select(.name == "scout-evaluation") | {interval, lastEvaluation, rules}'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alertname == "ScoutEvaluationCheck") | {labels, state, activeAt, value}'
```

Repeat these commands while the rule arrives and evaluates. In the rules response, inspect `health`, `lastError`, `state` and `duration`. A loaded rule with `health: ok` and a recent `lastEvaluation` has run successfully. A rule with no current alert instances can be `inactive`; its absence from the alerts response alone does not prove that it was never loaded.

## What happens at each evaluation

Prometheus reads the latest scraped samples and evaluates the expression every 15 seconds here. The first matching evaluation starts `activeAt` for each alert's label set. Prometheus keeps that instance `pending` until an evaluation finds that at least one minute has passed with the same instance still matching. That evaluation changes it to **firing**, which means Prometheus may send it to Alertmanager.

`for` does not run a second query continuously between evaluations. If an evaluation returns no matching series before the minute ends, that instance becomes inactive and loses its pending time. A changed label set creates a different instance with a new timer. Put changing measurements in annotations, which are descriptive fields, rather than in labels.

The comparison must filter out healthy values for a real fault alert. With `> bool 0.1`, Prometheus returns series with values of zero or one. An alerting rule treats both as present series, so both can become alerts. Use `> 0.1` when the rule should alert only above the threshold.

## Follow the send path

Prometheus queues firing alerts for its notifier, which sends batches to the configured Alertmanager endpoint. Prometheus refreshes firing alerts while they remain active and sends resolution information when they end. Successful evaluation proves the condition; it does not prove a successful send or notification.

Inspect the discovered Alertmanager endpoint and the alerts it holds:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alertmanagers' | jq '.data'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts' | jq '.[] | select(.labels.alertname == "ScoutEvaluationCheck") | {labels, receivers, status}'
```

Look for an entry in `activeAlertmanagers`, then the same alert labels in Alertmanager. Prometheus says `firing`; Alertmanager says `active` or `suppressed`. A receiver named `null` means that Alertmanager accepted the alert but selected a receiver that sends nothing. A receiver assignment alone does not prove that its webhook accepted a request; read the receiver logs to prove delivery.

For the user interface (UI), leave these commands running in two separate terminals:

```sh
kubectl -n monitoring port-forward service/kps-prometheus 9090:9090
```

```sh
kubectl -n monitoring port-forward service/kps-alertmanager 9093:9093
```

Open `http://127.0.0.1:9090/alerts` to inspect rule states and `http://127.0.0.1:9093` to inspect received alerts. The same labels connect the two views. Scraping, rule evaluation, the `for` duration, configuration reload and Alertmanager grouping each add delay. A query window can add further delay as older samples leave the range; there is no single fixed delivery time.

You can now locate a delay at evaluation, transport or notification. The rules response proves loading and evaluation, while the alerts responses show what each component currently holds. These checks narrow a missing alert to the component that needs attention.

## Common pitfalls

> [!WARNING]
> - **Looking only at the alerts response.** An inactive loaded rule is visible in the rules response even when no alert instance exists.
> - **Changing a label during `for`.** A different label set starts a new instance and waiting period.
> - **Using a `bool` comparison for a fault alert.** A returned zero still creates an alert instance.

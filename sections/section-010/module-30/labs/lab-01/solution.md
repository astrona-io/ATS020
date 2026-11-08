# Solution Walkthrough

Create the team's rule, repair its route and silence the separate maintenance
alert. Prometheus decides whether an alert fires. Alertmanager chooses its
receiver and applies silences.

| Goal | Component | Evidence |
| --- | --- | --- |
| Select and load a rule | Prometheus Operator and Prometheus | Rules API |
| Wait for a condition | Prometheus | Alerts API and `state` |
| Route a notification | Alertmanager | Receiver assignment and webhook log |
| Suppress maintenance notifications | Alertmanager | Active silence and `silencedBy` |

## The feedback loop

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-30/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

Before making changes, expect `rule-loaded`, `alert-firing`, `receiver-routed`
and `maintenance-silenced` to fail. The rule does not exist, the route matches
the wrong team and no maintenance silence exists.

## Step 1: Inspect the missing rule and wrong route

An application programming interface (API) returns the running component's
state. Read the selectors, existing configuration and received alerts:

```sh
kubectl -n monitoring get prometheus kps-prometheus -o json | jq '.spec | {ruleSelector, ruleNamespaceSelector}'
kubectl -n starfleet get prometheusrules
kubectl -n starfleet get alertmanagerconfig scout-routing -o yaml
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts' | jq '.[] | {labels, receivers, status}'
```

Look for the `release: kps` selector, the wrong `team=outpost` matcher and the
received `ProbeMaintenance` alert. No check changes yet; the watch terminal
still shows all four checks failing.

## Step 2: Write and load the rule

Save this as `prometheusrule-scout-errors.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-errors
  namespace: starfleet
  labels:
    release: kps
spec:
  groups:
  - name: scout-errors
    interval: 15s
    rules:
    - alert: ScoutErrorRate
      expr: sum by (namespace) (rate(http_requests_total{job="scout",namespace="starfleet",status="500"}[1m]))
        > 0.1
      for: 1m
      labels:
        team: scout
        severity: warning
```

`metadata.labels` makes the operator select this object. `groups` holds a rule
group, and `interval` evaluates it every 15 seconds. `expr` uses Prometheus
Query Language (PromQL) to sum per-second error rates while preserving
`namespace`. `for` requires the condition to remain true for one minute.
The rule labels set the team for routing and the severity for notification
handling.

Apply it:

```sh
kubectl apply -f prometheusrule-scout-errors.yaml
```

Then check the result:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/rules' | jq '.data.groups[] | select(.name == "scout-errors") | .rules'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alertname == "ScoutErrorRate") | {labels, state, activeAt}'
```

Allow time for configuration propagation, rate samples and the `for` duration.
The rules response should contain `ScoutErrorRate` with `health: ok` and
`duration: 60`. Its instances move from `pending` to `firing`.

**Run the check:** the watch terminal shows `rule-loaded` passing, then
`alert-firing` once the one-minute condition has held. The route and silence
checks still need their changes.

## Step 3: Route the team alert to the webhook

Save this as `alertmanagerconfig-scout-routing.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: scout-routing
  namespace: starfleet
spec:
  route:
    receiver: scout-webhook
    matchers:
    - name: team
      value: scout
      matchType: '='
    groupBy:
    - namespace
    - alertname
    groupWait: 5s
    groupInterval: 15s
    repeatInterval: 5m
  receivers:
  - name: scout-webhook
    webhookConfigs:
    - url: http://alert-receiver.monitoring:8080/
      sendResolved: true
```

`route.receiver` names a receiver declared in `receivers`. The equality
matcher selects `team=scout`. `groupBy` groups instances by namespace and
alert name. The three timing fields control the first message, changed-group
updates and repeated unchanged messages. `webhookConfigs` sets the existing
receiver URL, and `sendResolved` also sends a resolution notification.

Apply it:

```sh
kubectl apply -f alertmanagerconfig-scout-routing.yaml
```

Then check the result:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/status' | jq -r '.config.original'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts' | jq '.[] | select(.labels.alertname == "ScoutErrorRate") | {labels, receivers, status}'
kubectl -n monitoring logs deploy/alert-receiver
```

Look for the generated receiver
`starfleet/scout-routing/scout-webhook`, the injected namespace matcher and
the firing notification in the receiver log. Alertmanager must both select
the receiver and deliver the request. Wait for propagation and grouping if
the receiver assignment changes before the log appears.

**Run the check:** the watch terminal shows `rule-loaded`, `alert-firing` and
`receiver-routed` passing. `maintenance-silenced` still needs a silence.

## Step 4: Silence only the maintenance alert

`amtool` is the Alertmanager command line client. Run it inside the
Alertmanager container, where it is already installed:

```sh
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- amtool silence add alertname=ProbeMaintenance namespace=starfleet --duration=30m --author=platform --comment='probe maintenance window' --alertmanager.url=http://localhost:9093
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- amtool silence query --alertmanager.url=http://localhost:9093
```

The first command returns a silence identifier. Check the two matchers,
author, comment and the 30-minute window. Do not expire this silence before
finishing the task.

To use the user interface (UI) instead, forward the Service in another
terminal:

```sh
kubectl -n monitoring port-forward service/kps-alertmanager 9093:9093
```

Open `http://127.0.0.1:9093`, create a silence with the same two equality
matchers, set a 30-minute duration, author `platform` and comment
`probe maintenance window`, then create it. Use one method. Both create the
same API object.

Inspect the API result:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/silences' | jq '.[] | {id, matchers, startsAt, endsAt, createdBy, comment, status}'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts' | jq '.[] | select(.labels.alertname == "ProbeMaintenance") | {labels, status}'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alertname == "ProbeMaintenance") | {labels, state}'
```

Look for an active silence, its identifier in `status.silencedBy`, and the
maintenance alert still firing in Prometheus. Silencing stops notifications;
it does not change the underlying rule.

**Run the check:** the watch terminal shows all four checks passing.

## Step 5: Submit

Once all four checks pass, press Ctrl-C to stop the watch terminal and submit
once. The watch terminal should still have shown `rule-loaded`,
`alert-firing`, `receiver-routed` and `maintenance-silenced` passing before
you stopped it.

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-30/labs/lab-01
```

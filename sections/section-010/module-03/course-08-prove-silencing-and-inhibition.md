# Prove Silencing And Inhibition

During maintenance, an alert should remain visible in Prometheus while notifications stop for a limited time. A **silence** suppresses alerts that match its labels during a time window. An **inhibition rule** suppresses target alerts while a matching source alert exists. They solve different problems and leave different evidence in Alertmanager.

<!-- astrona:playground:renew -->

Save this as `prometheusrule-scout-inhibition.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-inhibition
  namespace: starfleet
  labels:
    release: kps
spec:
  groups:
    - name: scout-inhibition
      rules:
        - alert: ScoutLatency
          expr: vector(1)
          labels:
            namespace: starfleet
            team: scout-inhibit
            severity: critical
        - alert: ScoutLatency
          expr: vector(1)
          labels:
            namespace: starfleet
            team: scout-inhibit
            severity: warning
```

`vector(1)` returns a single constant series. These are diagnostic fixtures, not real latency measurements. The alerts have the same name but different severity labels, so they are separate instances. There is no `for` duration; they can fire on their first successful evaluation.

Apply it:

```sh
kubectl apply -f prometheusrule-scout-inhibition.yaml
```

Save this as `alertmanagerconfig-scout-inhibition.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: scout-inhibition
  namespace: starfleet
spec:
  route:
    receiver: scout-webhook
    matchers:
      - name: team
        value: scout-inhibit
        matchType: "="
    groupBy: [namespace, alertname]
    groupWait: 10s
    groupInterval: 1m
    repeatInterval: 5m
  receivers:
    - name: scout-webhook
      webhookConfigs:
        - url: http://alert-receiver.monitoring:8080/
  inhibitRules:
    - sourceMatch:
        - name: team
          value: scout-inhibit
          matchType: "="
        - name: severity
          value: critical
          matchType: "="
      targetMatch:
        - name: team
          value: scout-inhibit
          matchType: "="
        - name: severity
          value: warning
          matchType: "="
      equal: [namespace, team, alertname]
```

`sourceMatch` identifies the critical source and `targetMatch` identifies warning targets. `equal` requires both alerts to carry the same values for those labels. The operator also limits both sides to this resource's namespace under the default namespace strategy. In the generated configuration these fields become `source_matchers`, `target_matchers` and `equal`.

Apply it:

```sh
kubectl apply -f alertmanagerconfig-scout-inhibition.yaml
```

Then check the result through the Alertmanager application programming interface (API):

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/status' | jq -r '.config.original'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts' | jq '.[] | select(.labels.alertname == "ScoutLatency") | {labels, status}'
```

Look for the merged inhibition rule. Once both alert instances arrive, the warning instance should have `status.state: suppressed` and a nonempty `status.inhibitedBy`. The critical instance is the source. Existing chart inhibition rules can also contribute identifiers, so inspect all the matchers in the loaded configuration when explaining suppression.

## Create and list a silence

`amtool` is the Alertmanager command line client, included in the Alertmanager container. Create a ten-minute silence for only the warning instance, with an author and a comment:

```sh
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- amtool silence add alertname=ScoutLatency namespace=starfleet severity=warning --duration=10m --author=platform --comment='scout latency maintenance' --alertmanager.url=http://localhost:9093
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- amtool silence query --alertmanager.url=http://localhost:9093
```

The add command prints the silence identifier. Keep that identifier to expire it later. The query lists silence matchers and end times. All three matchers must match; the namespace prevents the silence from suppressing the same alert name for another team namespace.

Check the API evidence as well:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/silences' | jq '.[] | {id, matchers, startsAt, endsAt, createdBy, comment, status}'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts' | jq '.[] | select(.labels.alertname == "ScoutLatency") | {labels, status}'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alertname == "ScoutLatency") | {labels, state}'
```

The silence has `status.state: active` during its window. The warning alert's `status.silencedBy` should contain its identifier. It can also have `inhibitedBy` at the same time. Both alerts stay firing in Prometheus: suppression changes notification handling, not rule evaluation. In the Alertmanager browser interface you can create the same silence by entering these matchers, a duration, an author and a comment; the APIs above check either method.

## Expire and distinguish the causes

Replace `<SILENCE-ID>` with the identifier you read, then expire it early:

```sh
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- amtool silence expire <SILENCE-ID> --alertmanager.url=http://localhost:9093
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/silences' | jq '.[] | {id, status}'
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-alertmanager:9093/proxy/api/v2/alerts' | jq '.[] | select(.labels.alertname == "ScoutLatency") | {labels, status}'
```

Look for `expired` on the silence. The warning alert can remain suppressed because the critical source still inhibits it. Expiring a silence removes only that silence; it does not disable inhibition or bypass notification timing. Likewise, a silence cannot recall a notification already delivered.

Missing labels in `equal` count as empty values. If both source and target lack a label named there, they can still compare equal. Use labels that both alerts actually carry and source and target matchers that identify the intended severities. Otherwise one critical alert may suppress unrelated warnings.

You can now create, list and expire a scoped silence and distinguish it from inhibition using `silencedBy` and `inhibitedBy`. Suppression should leave a clear reason and an end condition while Prometheus continues to show the underlying alert.

## Common pitfalls

> [!WARNING]
> - **Reading only `suppressed`.** Inspect `silencedBy` and `inhibitedBy` to find every reason notifications stopped.
> - **Using absent labels in `equal`.** Two missing values compare equal and can broaden inhibition.
> - **Deleting a firing rule for maintenance.** Use a silence with a duration and comment so evaluation continues and the suppression ends.

## Your mission: Route A Team Alert And Silence Maintenance

You can now prove loading, routing and suppression at each component. Repair a team's alert path and create a scoped maintenance silence in a separate graded lab.

Pause the playground, then start the lab:

```sh
astrona stop ats-020-playground-010-03
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-03/labs/lab-01
```

Use the walkthrough's watch command while working. When ready, finish the attempt:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-03/labs/lab-01
```

If you abandoned the attempt before submitting, remove the lab. Then resume the playground:

```sh
astrona destroy ats-020-lab-010-03
astrona start ats-020-playground-010-03
```

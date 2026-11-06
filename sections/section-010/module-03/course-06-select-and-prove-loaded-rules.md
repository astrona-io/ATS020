# Select And Prove Loaded Rules

A `PrometheusRule` can exist in Kubernetes and never reach Prometheus. The Prometheus Operator first selects namespaces, then selects rule objects within them. A valid object outside those selectors is ignored without a rule evaluation error. You need the running rules API to distinguish an ignored rule from an inactive one.

<!-- astrona:playground:renew -->

Save this as `prometheusrule-scout-selector.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: scout-selector
  namespace: starfleet
  labels:
    release: outpost
spec:
  groups:
    - name: scout-selector
      rules:
        - alert: ScoutSelectorCheck
          expr: up{namespace="starfleet",job="scout"} == 0
          for: 1m
          labels:
            severity: warning
```

The wrong `release` label is deliberate. The expression uses the `up` scrape result metric and alerts on a failed scrape. Healthy targets should leave this rule inactive once it is loaded.

Apply it:

```sh
kubectl apply -f prometheusrule-scout-selector.yaml
```

Then check the result. The **application programming interface (API)** is the structured interface used by the following commands:

```sh
kubectl -n monitoring get prometheus kps-prometheus -o json | jq '.spec | {ruleNamespaceSelector, ruleSelector}'
kubectl -n starfleet get prometheusrule scout-selector --show-labels
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/rules' | jq '[.data.groups[].rules[] | select(.name == "ScoutSelectorCheck")]'
```

Expect the object to exist but no matching loaded rule. The playground's Prometheus resource selects `release: kps`, and the object has `release: outpost`. This mismatch is valid Kubernetes configuration. It does not require a warning event because the operator was never asked to load that object.

## Two selectors with different defaults

`ruleNamespaceSelector` matches labels on **Namespace objects**. It does not match alert labels or the labels on a PrometheusRule. `ruleSelector` matches `metadata.labels` on **PrometheusRule objects** in those namespaces. The operator must pass both tests before it generates a rule file.

| Field on the Prometheus resource | Empty object `{}` | Null or omitted |
| --- | --- | --- |
| `ruleNamespaceSelector` | Every namespace | Only the Prometheus resource's namespace |
| `ruleSelector` | Every PrometheusRule in eligible namespaces | No PrometheusRules |

These are the operator's API semantics. Chart values are a separate input: kube-prometheus-stack has `ruleSelectorNilUsesHelmValues: true` by default. An empty rule selector in its values therefore renders a release-label selector here. Inspect the rendered or live Prometheus resource rather than assuming that an empty chart value selects everything.

Correct the resource label without widening the Prometheus selectors:

```sh
kubectl -n starfleet label prometheusrule scout-selector release=kps --overwrite
```

Then check the running rules again after the operator has reconciled the change:

```sh
kubectl get --raw '/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/rules' | jq '.data.groups[] | select(.name == "scout-selector") | {file, lastEvaluation, rules}'
```

Look for `ScoutSelectorCheck`, its query, `health: ok` and `state: inactive` while the targets remain healthy. The `file` field identifies the loaded rule file. This response proves loading even though the rule does not fire. `kubectl apply` proves only that Kubernetes accepted the object.

## Trace a selected rule that still fails

The operator converts selected rule groups into ConfigMaps, which are Kubernetes objects that hold configuration text. Prometheus mounts the generated files, and the configuration reloader asks Prometheus to reload changes. A selected rule may still fail validation or evaluation, so do not stop at its labels.

Read the object events, the operator logs and the rule health together:

```sh
kubectl -n starfleet describe prometheusrule scout-selector
kubectl -n monitoring logs deploy/kps-operator --since=10m
kubectl -n monitoring get configmaps -l prometheus=kps-prometheus
```

A rejected rule may have a warning event or an operator log entry explaining the invalid field or expression. An evaluation failure appears in the loaded rule's `health` and `lastError`. An object that does not match the selector may have neither. Reload and mounted-file propagation take time, so repeat the rules query before concluding that a correct label fix failed.

You can now separate namespace selection, object selection and rule evaluation. The running rules response is the final proof that Prometheus received the intended query; the operator's logs and object events help explain failures along that path.

## Common pitfalls

> [!WARNING]
> - **Labelling only the alert.** `spec.groups[].rules[].labels` controls alert labels; selection reads `metadata.labels` on the rule object.
> - **Treating null and `{}` as equivalent.** Their selection behavior differs, and chart rendering can add another default.
> - **Widening the server selector to fix one object.** Correct the intended object's labels and keep the server's selection boundary.

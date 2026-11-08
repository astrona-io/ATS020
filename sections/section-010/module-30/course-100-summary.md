# Summary

Alerting is two components working together: Prometheus decides that something is wrong, and Alertmanager decides who hears about it and how often. An alert moves from a PromQL condition to a receiver and can return to quiet when the condition ends.

## What you learned

A PrometheusRule holds rule groups that Prometheus evaluates on an interval. A recording rule stores the result of an expression as a new series under a `level:metric:operations` name; an alerting rule raises an alert while its expression returns a result for at least `for`, and adds `labels` for routing and `annotations` for people. A ratio built from a series that does not exist is empty, not zero.

Between `kubectl apply` and a loaded rule sit two selectors, a validation step, a generated ConfigMap and a reload. An empty namespace selector matches all namespaces, while an omitted one matches only the Prometheus namespace; an empty rule selector matches every rule object, while an omitted one matches none, and the chart renders a `release` label selector for both. A selector mismatch leaves no event and no error, so the rules API is the only proof of loading, and `health` and `lastError` there report evaluation errors.

An alert is `inactive` while its expression returns nothing, `pending` while it has returned a result for less than `for`, and `firing` after that; when the expression goes empty again the alert is resolved. Prometheus keeps one instance per label set, so a label change starts a new instance with its own timer, and a pending instance is dropped the moment its label set disappears. Scraping, evaluation, query windows and `for` each add delay. Prometheus re-sends a firing alert to Alertmanager about once a minute with an `endsAt` a few minutes ahead, and in Alertmanager the alert is `active`, or `suppressed` when silenced or inhibited.

Alertmanager routes alerts down a tree of label matchers to receivers. Every matcher on a route must match, children are tried in order, the first match wins unless it sets `continue`, and a node whose children all miss handles the alert itself; children inherit receiver, grouping and timing from their parent. `group_by`, `group_wait`, `group_interval` and `repeat_interval` decide how alerts are bundled and how often they are sent again. An AlertmanagerConfig adds a team's route and receivers; under the default namespace matcher strategy, the operator adds a matcher on the AlertmanagerConfig's own namespace, renames the receiver to `<namespace>/<name>/<receiver>`, sets `continue: true` and places team routes, sorted by name, before the chart's own routes.

A silence mutes matching alerts in Alertmanager for a set time and leaves Prometheus untouched; `amtool silence add`, `query` and `expire` manage it, and the silence stage runs after inhibition and before deduplication, so it never recalls a notification already sent. An inhibition rule mutes target alerts while a source alert fires and both share the values of the `equal` labels; a label missing from both counts as equal. The fields `silencedBy` and `inhibitedBy` name every reason an alert is suppressed, and receiver logs and notification counters prove what was and was not delivered.

The key facts to remember are these:

- Prometheus fires alerts; Alertmanager routes, groups, silences and inhibits them.
- PrometheusRules need the label `ruleSelector` matches, and only the rules API proves they loaded.
- Route order and `continue` are the whole precedence rule; there is no "most specific wins".
- Under the default namespace matcher strategy, a team AlertmanagerConfig routes alerts from its own namespace.
- Silence with several matchers and a comment, and expire it only when the problem is gone.

<!-- astrona:playground:destroy -->

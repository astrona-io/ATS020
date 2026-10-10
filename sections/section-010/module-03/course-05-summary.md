# Summary

Alerting is two components working together: Prometheus decides that something is wrong, and Alertmanager decides who hears about it and how often. This module followed one alert from a PromQL condition to a message and back to quiet.

## What you learned

A PrometheusRule holds rule groups that Prometheus evaluates on an interval. A recording rule stores the result of an expression as a new series under a `level:metric:operations` name; an alerting rule raises an alert while its expression returns a result for at least `for`, and adds `labels` for routing and `annotations` for people. The Prometheus resource only loads PrometheusRules its `ruleSelector` matches, here those with `release: kps`. A ratio built from a series that does not exist is empty, not zero.

An alert is `inactive` while its expression returns nothing, `pending` while it has returned a result for less than `for`, and `firing` after that; when the expression goes empty again the alert is resolved. The delay before `firing` is the scrape interval plus the evaluation interval plus `for`. A firing alert is sent to Alertmanager, where its state is `active`, or `suppressed` when silenced or inhibited.

Alertmanager routes alerts down a tree of label matchers to receivers, and `group_by`, `group_wait`, `group_interval` and `repeat_interval` decide how alerts are bundled and how often they are sent again. An AlertmanagerConfig adds a team's route and receivers as a child of the root route. The operator adds a matcher on the AlertmanagerConfig's own namespace, renames the receiver to `<namespace>/<name>/<receiver>`, and sets `continue: true`.

A silence mutes matching alerts in Alertmanager for a set time and leaves Prometheus untouched; `amtool silence add`, `query` and `expire` manage it. The proof that it works is the receiver and `alertmanager_notifications_total`, not only the `suppressed` state. Inhibition rules mute follow-on alerts while a more important one fires. The key facts to remember are these:

- Prometheus fires alerts; Alertmanager routes, groups and silences them.
- PrometheusRules need the label `ruleSelector` matches.
- An AlertmanagerConfig only routes alerts from its own namespace.
- Silence with several matchers and a comment, and expire it only when the problem is gone.

<!-- astrona:playground:destroy -->

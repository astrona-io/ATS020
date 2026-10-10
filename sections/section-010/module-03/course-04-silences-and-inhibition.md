# Silences And Inhibition

Some alerts are true and still unwanted. During planned maintenance, or while someone already works on the problem, every new notification only adds noise. Deleting or editing the alerting rule would hide the problem for everyone and is easy to forget to undo. Alertmanager has two cleaner tools: a **silence** mutes matching alerts for a fixed time, and an **inhibition rule** mutes some alerts while another, more important one fires. This part silences `ScoutHighErrorRatio`, proves no notification goes out, and lets the silence end.

## Add a silence

A silence is a set of label matchers plus a start time, an end time, an author and a comment. While it is active, Alertmanager still receives and tracks matching alerts, but sends no notifications for them. It does not touch Prometheus: the alert keeps `firing` there.

`amtool` is Alertmanager's command-line tool, and it is part of the Alertmanager container image, so you can run it inside the Alertmanager pod. The error loop from earlier must still be running, so the alert is still firing. Add a silence for 30 minutes:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- \
  amtool silence add alertname=ScoutHighErrorRatio namespace=starfleet \
  --duration=30m --author=platform --comment="known issue, fix in progress" \
  --alertmanager.url=http://localhost:9093
```

`amtool` prints the ID of the new silence:

```text
f82ebb4a-42a4-4e4b-896b-168680df659d
```

Your ID will differ; keep it, you need it to end the silence. List the active silences to check the matchers and the end time:

```sh
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- \
  amtool silence query --alertmanager.url=http://localhost:9093
```

You should see something like:

```text
ID                                    Matchers                                               Ends At                  Created By  Comment
f82ebb4a-42a4-4e4b-896b-168680df659d  alertname="ScoutHighErrorRatio" namespace="starfleet"  2026-10-10 16:50:05 UTC  platform    known issue, fix in progress
```

Match on more than the alert name. `namespace=starfleet` keeps the silence from muting the same alert for other teams. The browser page at `http://127.0.0.1:9093` has a form for the same thing.

## Prove the silence works

First, check the alert's state in Alertmanager, with the Alertmanager port-forward on `9093` still running:

```sh
curl -s http://127.0.0.1:9093/api/v2/alerts | jq -r '.[] | "\(.labels.alertname)\t\(.status.state)\t\(.status.silencedBy | join(","))"'
```

You should see something like:

```text
ScoutHighErrorRatio	suppressed	f82ebb4a-42a4-4e4b-896b-168680df659d
```

The state changed from `active` to `suppressed`, and `silencedBy` names the silence. `amtool alert query` hides suppressed alerts by default; add `--silenced` to list them.

A state is not the proof, though. The proof is that no notification goes out. The route's `repeatInterval` is five minutes, so without the silence the receiver would get the same firing alert again about five minutes after the first notification. Wait a little longer than that, then read the receiver's log and the notification counter:

```sh
kubectl -n monitoring logs deploy/alert-receiver
curl -s http://127.0.0.1:9093/metrics | grep -E '^alertmanager_notifications_total\{.*webhook'
```

You should see something like:

```text
starfleet/starfleet/starfleet-webhook firing ScoutHighErrorRatio namespace=starfleet severity=warning startsAt=2026-10-10T16:18:10.604Z
alertmanager_notifications_total{integration="webhook"} 1
```

Still one notification after more than five minutes, while the alert kept firing in Prometheus the whole time. The silence held.

## End the silence

A silence ends on its own at its end time. To end it earlier, expire it by ID:

```sh
kubectl -n monitoring exec alertmanager-kps-alertmanager-0 -c alertmanager -- \
  amtool silence expire <SILENCE-ID> --alertmanager.url=http://localhost:9093
```

Replace `<SILENCE-ID>` with the ID `amtool silence add` printed. Then let the error loop finish; it stops on its own after ten minutes. Pressing `Ctrl+C` in its terminal stops your local `kubectl`, but not always the loop inside the pod, so waiting is the reliable way. Wait until a few minutes after the loop has ended, and read the receiver's log again:

```sh
kubectl -n monitoring logs deploy/alert-receiver
```

You should see something like:

```text
starfleet/starfleet/starfleet-webhook firing ScoutHighErrorRatio namespace=starfleet severity=warning startsAt=2026-10-10T16:18:10.604Z
starfleet/starfleet/starfleet-webhook firing ScoutHighErrorRatio namespace=starfleet severity=warning startsAt=2026-10-10T16:18:10.604Z
starfleet/starfleet/starfleet-webhook resolved ScoutHighErrorRatio namespace=starfleet severity=warning startsAt=2026-10-10T16:18:10.604Z
```

Two new lines arrived. As soon as the silence expired, the alert was still firing and its repeat interval had long passed, so Alertmanager sent it again. When the loop ended, the one-minute error ratio dropped below 5%, the alert left `firing` in Prometheus, and Alertmanager sent `resolved`, because the receiver has `sendResolved: true`. Expiring a silence while the problem still exists brings the notifications straight back.

## Inhibition

An **inhibition rule** mutes alerts that match a target while an alert that matches a source is firing, when both have the same values for a list of labels. It is for alerts that follow from another one: when a node is down, the alerts for every pod on it add nothing.

The Helm chart's default Alertmanager configuration already has such rules. The first one, in the running configuration, reads:

```text
inhibit_rules:
- source_matchers:
  - severity="critical"
  target_matchers:
  - severity=~"warning|info"
  equal:
  - namespace
  - alertname
```

While an alert with `severity="critical"` fires, alerts with the same `namespace` and `alertname` and a `severity` of `warning` or `info` are muted. If `ScoutHighErrorRatio` had a second rule with the same name and a higher threshold labelled `critical`, the `warning` version would go quiet as soon as the `critical` one fired. Inhibited alerts show the state `suppressed` with an `inhibitedBy` field, the same way silenced ones show `silencedBy`.

You can now mute an alert for a planned window with a silence, prove from the receiver and the counter that nothing was sent, end the silence early, and read the inhibition rules that mute follow-on alerts. Together with rules and routes, that is the whole path from a PromQL condition to a message a person reads.

## Common pitfalls

> [!WARNING]
> - **Silencing with only `alertname`.** The silence then mutes the alert for every namespace and team.
> - **Deleting or editing the rule instead of silencing.** The problem disappears for everyone, with no end time and no comment.
> - **Expecting a silence to change Prometheus.** The alert keeps `firing` there; only Alertmanager stops notifying.
> - **Expiring a silence while the problem still exists.** The next notification goes out right away.

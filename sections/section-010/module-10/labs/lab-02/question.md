# Question

Solve this question on: `terminal`

## Scenario

The `scout` and `probe` Deployments in `starfleet` report a queue metric.
The Deployment `prometheus-raw` in `monitoring` runs plain Prometheus 3.15.0
without the Prometheus Operator. Its ConfigMap `prometheus-raw` holds
`prometheus.yml`, mounted at `/etc/prometheus/prometheus.yml`. The Service
`prometheus-raw` exposes port `9090`, and `--web.enable-lifecycle` is enabled.

The job `starfleet-pods` discovers Pods but keeps only the Pod label value
`telemetry: primary`. The missing workload uses `telemetry: reserve`.
The `shuttle` Deployment uses `telemetry: disabled` and must stay excluded.
All three Deployments start with one replica. They run a small synthetic
metric server, rather than the applications used in the playground.

## Tasks

1. **Extend discovery.** Read `prometheus.yml` and extend the existing
   `starfleet-pods` job. Keep `kubernetes_sd_configs` with `role: pod` in
   `starfleet`, and use `relabel_configs` with `action: keep` to accept both
   `primary` and `reserve` for the Pod label `telemetry`. Keep the port filter
   `metrics`, the ready-Pod filter and the labels `namespace`, `pod` and
   `deployment`. Do not replace discovery with static targets.
2. **Load the change.** Restart Prometheus or reload its configuration.
   The active target list for `starfleet-pods` must contain exactly one healthy
   target per ready `primary` or `reserve` Pod, with its live address and
   matching `namespace`, `pod` and `deployment` labels. Exclude disabled Pods.
3. **Act on the metric.** Use Prometheus Query Language (PromQL) to run
   `sum by (deployment) (starfleet_queue_items{job="starfleet-pods",namespace="starfleet"})`.
   A gauge is a metric whose value can rise or fall; this gauge reports
   synthetic queued items per Pod. Compare both workload totals and scale
   only the Deployment with the highest total to **three ready replicas**.
   Keep the other two Deployments at one ready replica each.

Keep workload labels, images, metric server code and `QUEUE_ITEMS` values
unchanged. Keep the `prometheus-raw` ConfigMap, Deployment and Service in
`monitoring`. Do not install the Operator or create monitor resources.

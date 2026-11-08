# Section 010: Metrics And Alerting With Prometheus

Makes the reader able to get any workload's metrics into Prometheus through the Prometheus Operator or raw scrape configuration, query them with PromQL, and turn a query into an alert that reaches a receiver. It comes first because every later section (dashboards, SLOs, DORA metrics, incident triage) reads these metrics.

**Curriculum item covered:** Implementing Monitoring, Alerting, Logging, and Tracing Solutions

---

## What You Will Master

- Read the Prometheus targets page and the `up` metric to say which targets are scraped and which fail
- Write a ServiceMonitor that selects a Service by label and scrapes a named port and path
- Write a PodMonitor for pods that have no Service
- Find why a new monitor produces no target (Prometheus selector label, namespace selector, port name, path)
- Prove a scrape works with `up == 1` for every endpoint of the workload
- Extend raw Pod discovery with a keep rule, reload Prometheus and scale a Deployment chosen with `sum by`
- Select time series by metric name and label matchers, including regex matchers
- Calculate a per-second request rate from a counter with `rate()` and explain why `rate` is not used on a gauge
- Aggregate series with `sum by` and `without` to get one value per namespace or per status code
- Calculate an error ratio and a 95th-percentile latency with `histogram_quantile`
- Run a query from the command line against the Prometheus HTTP API and read the result with jq
- Write an alerting rule in a PrometheusRule with `expr`, `for`, labels and annotations
- Write a recording rule and query the new series it creates
- Read an alert's state (inactive, pending, firing) in Prometheus and in Alertmanager
- Route alerts by label to a receiver with an AlertmanagerConfig or the Alertmanager configuration
- Silence an alert for a time window and prove it stops notifying

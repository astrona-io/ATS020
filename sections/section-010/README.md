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

---

## The Learning Path

### 1. Scrape Workloads With ServiceMonitor And PodMonitor
*   **Module Reader:** **[Module 1: Scrape Workloads With ServiceMonitor And PodMonitor](./module-01/course.md)**
*   **Hands-on Playground:** `sections/section-010/module-01/playground` — kind cluster with trimmed kube-prometheus-stack 92.3.0 (one Prometheus replica and the Prometheus Operator only; Alertmanager, Grafana, node-exporter, kube-state-metrics, default rules and dashboards off). Namespace `starfleet` with `scout` (podinfo, Service with named port `http` 9898 exposing /metrics) and `shuttle`; namespace `outpost` with a second `scout` Deployment and no Service (for a PodMonitor). No ServiceMonitor or PodMonitor for the Starfleet app exists yet, so the first targets page shows only Prometheus itself.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-01/playground
    ```

*   **Raw configuration reading and lab:** Extend a Pod discovery job in `prometheus.yml`, load it and query a synthetic queue gauge to choose which Deployment to scale. The separate lab runs without an Operator: `sections/section-010/module-01/labs/lab-02` (20 minutes).

### 2. Query Metrics With PromQL
*   **Module Reader:** **[Module 2: Query Metrics With PromQL](./module-02/course.md)**
*   **Hands-on Playground:** `sections/section-010/module-02/playground` — Same trimmed stack as the scraping module, with ServiceMonitors for `scout` in `starfleet` and `scout` in `outpost` already applied and targets UP. A `shuttle` loop sends steady traffic to both `scout` workloads, plus `/status/500` and `/delay/1` requests to the `starfleet` `scout`, so error ratio and latency queries return non-zero values. Port-forward to Prometheus on 9090 documented.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-02/playground
    ```

### 3. Alert With PrometheusRule And Alertmanager
*   **Module Reader:** **[Module 3: Alert With PrometheusRule And Alertmanager](./module-03/course.md)**
*   **Hands-on Playground:** `sections/section-010/module-03/playground` — Trimmed kube-prometheus-stack with Prometheus and Alertmanager on, a ServiceMonitor for `scout` applied, and a webhook receiver pod in namespace `monitoring` (a small HTTP echo that logs every POST) so the reader can see notifications arrive. No PrometheusRule for the Starfleet app exists yet. `scout` answers `500` on demand when a request goes to `/status/500`.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-03/playground
    ```

*   **Parts:** Recording And Alerting Rules, Selecting And Loading PrometheusRules, The Alert Lifecycle, Routing Alerts With Alertmanager, Silences, Inhibition, Route Precedence And Grouping, Summary.
*   **Module lab:** [Route A Team Alert And Silence Maintenance](./module-03/labs/lab-01/README.md) — 25 minutes. Write a selected PrometheusRule, repair a team route to the webhook receiver and create an active 30-minute silence for a separate firing alert.

### Section Capstone Challenge
*   **Comprehensive Challenge:** Metrics And Alerting Capstone — `sections/section-010/capstone/labs/lab-01`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/capstone/labs/lab-01
    astrona submit -c .
    ```
*   **Hands-on Objective:** The namespace `frontier` runs `scout` with about one failing request in six, and three objects that do not work: a ServiceMonitor, a PrometheusRule and an AlertmanagerConfig. The reader fixes the monitor so Prometheus scrapes both pods, the recording rule `namespace:http_requests_error_ratio:rate1m`, the alert `ScoutHighErrorRatio` (above 5% for one minute) and the route for `team: frontier` to the webhook receiver. The grader compares the targets with the endpoints, the recorded ratio with a direct calculation, the loaded alert rule, and the receiver log.

---

## Ready for Assessment?

*   **[Take the Section 010 Knowledge Check](./quiz.yaml)**

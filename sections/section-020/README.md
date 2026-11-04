# Section 020: Dashboards And Logs

Makes the reader able to show metrics on a Grafana dashboard that is stored as code, and to collect pod logs with the OpenTelemetry Collector, enrich and filter them, and turn error lines into a Prometheus metric that a dashboard can draw. It also stores logs in Loki, queries them with LogQL and acts on the result. It follows metrics because dashboards draw PromQL queries, and logs are the next signal an operator reads.

**Curriculum item covered:** Implementing Monitoring, Alerting, Logging, and Tracing Solutions

---

## What You Will Master

- Add a Prometheus data source to Grafana with a provisioning file or a labelled ConfigMap
- Build a panel from a PromQL query and choose the right visualisation for a rate, a ratio and a latency
- Use a dashboard variable to switch the namespace shown on every panel
- Export a dashboard as JSON and load it through the Grafana sidecar ConfigMap so it survives a pod restart
- Read a pod's logs, its previous container's logs and its events with `kubectl logs` and `kubectl events`
- Deploy an OpenTelemetry Collector as a DaemonSet whose filelog receiver reads the container log files on each node
- Add Kubernetes metadata to each log record with the k8sattributes processor and drop unwanted records with the filter processor
- Check the logs pipeline end to end with the debug exporter and the Collector's own logs
- Turn error log lines into a Prometheus metric with the count connector and query it with PromQL
- Add and inspect a Loki data source in Grafana and change its Maximum lines in the web interface and through the API
- Write LogQL stream selectors, line filters and metric queries such as `count(rate({namespace="outpost"} |= "ERROR" [5m]))`
- Edit and save a dashboard panel's query and explain how that differs from a dashboard kept as code
- Use a query result to find the Pods that write errors and scale their controllers to 0

---

## The Learning Path

### 1. Build Grafana Dashboards As Code
*   **Module Reader:** **[Module 1: Build Grafana Dashboards As Code](./module-01/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-01/playground` — Trimmed kube-prometheus-stack with Prometheus and Grafana on (default dashboards off, sidecar for dashboards and data sources on, admin password set and shown in the playground guide). ServiceMonitors for `scout` in `starfleet` and `outpost` applied, traffic loop running. No Starfleet dashboard exists yet. Port-forward to Grafana on 3000 documented.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-01/playground
    ```

### 2. Collect Pod Logs With The OpenTelemetry Collector
*   **Module Reader:** **[Module 2: Collect Pod Logs With The OpenTelemetry Collector](./module-02/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-02/playground` — kind cluster with cert-manager, the OpenTelemetry Operator 0.160.0 and a trimmed Prometheus (Prometheus Operator and one Prometheus). The OpenTelemetry Collector contrib image 0.162.0 is preloaded, but no Collector is deployed yet. `scout` in `starfleet` and `probe` (go-httpbin) in `outpost`, with a traffic loop in `shuttle` that makes `probe` log both 200 and 500 responses. No log storage backend: logs are read with the debug exporter and counted into a Prometheus metric.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-02/playground
    ```

### 3. Query Logs With Loki And LogQL
*   **Module Reader:** **[Module 3: Query Logs With Loki And LogQL](./module-03/course.md)**
*   **Hands-on Playground:** `sections/section-020/module-03/playground` — Trimmed kube-prometheus-stack with Grafana only, Loki 3.7.9 in single-binary mode, and a Collector DaemonSet as plumbing that sends the logs of `outpost` and `starfleet` to Loki. A saved dashboard `Outpost Logs` exists, and no data source yet. Grafana on port-forward 3300 and Loki on 3100.
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-03/playground
    ```

### Section Capstone Challenge
*   **Comprehensive Challenge:** Dashboards And Logs Capstone — `sections/section-020/capstone/labs/lab-01`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/capstone/labs/lab-01
    astrona submit -c .
    ```
*   **Hands-on Objective:** The on-call team wants one dashboard for `outpost`. The reader creates an OpenTelemetryCollector `logs` (DaemonSet, `file_log` receiver, `k8s_attributes` processor, `count` connector) that turns `level=ERROR` log lines of `probe` into `log_error_lines_total`, gives its service account read access to pods only, makes Prometheus scrape port `8889`, and fixes the dashboard ConfigMap so Grafana provisions `outpost-overview` with three panels that show data. The grader checks the target, that the metric rises, the Collector permissions, the provisioned dashboard and each panel query.

*   **Comprehensive Challenge:** Trace One Incident Through Grafana, Prometheus And Loki — `sections/section-020/capstone/labs/lab-02`
    ```bash
    astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/capstone/labs/lab-02
    astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/capstone/labs/lab-02
    ```
*   **Hands-on Objective:** One service in `outpost` fails because of a wrong environment value. The reader adds a Loki data source with Maximum lines `500`, corrects the Prometheus and Loki panels of a saved dashboard, saves the failing Deployment and the bad path to files, and fixes the Deployment. The grader compares the files with Prometheus and Loki and proves recovery from live data.

---

## Ready for Assessment?

*   **[Take the Section 020 Knowledge Check](./quiz.yaml)**

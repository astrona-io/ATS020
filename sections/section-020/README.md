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

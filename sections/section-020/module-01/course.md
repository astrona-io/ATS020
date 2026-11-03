# Build Grafana Dashboards As Code

Prometheus answers a query when you ask it. During an incident, nobody has time to type five queries and compare the numbers by hand. A dashboard runs those queries for you, every 30 seconds, and draws the results side by side, so a rise in errors and a rise in latency show up together on one screen.

Grafana is the tool most platforms use for this job. Grafana is a web application that reads data from a **data source**, a connection to a backend such as Prometheus, and draws it on **dashboards**, pages made of **panels**. Each panel runs one or more queries and draws the result as a graph, a single number or a table. Grafana can store a dashboard in its own database, but a dashboard that only lives in that database is lost when the pod restarts with empty storage, and nobody can review a change to it.

Keep one sentence in mind for this module: **provision dashboard files to restore them when Grafana starts with an empty database.** You will provision the data source and the dashboards from Kubernetes ConfigMaps, so they come back after every restart and live next to the rest of the platform's configuration.

The module has four parts. **Grafana's Parts And A Provisioned Data Source** shows the containers in the Grafana pod and adds Prometheus as a data source from a labelled ConfigMap. **Panels For Rate, Error Ratio And Latency** writes a dashboard as JSON with one panel for each kind of question and checks every panel's query through Grafana. **A Namespace Variable For Every Panel** adds a drop-down list that switches all panels between `starfleet` and `outpost`. **Dashboards That Survive A Restart** proves that a dashboard saved only in Grafana is lost on restart, exports it as JSON, loads it from a ConfigMap and finds the reason when a dashboard does not appear.

## Learning objectives

After this module you can:

- Add a Prometheus data source to Grafana with a provisioning file or a labelled ConfigMap.
- Build a panel from a PromQL query and choose the right visualisation for a rate, a ratio and a latency.
- Use a dashboard variable to switch the namespace shown on every panel.
- Export a dashboard as JSON and load it through the Grafana sidecar ConfigMap so it survives a pod restart.

## Before you start

You need Kubernetes basics, `kubectl port-forward` and `kubectl logs`, and `curl` and `jq` on your machine. You need to read PromQL (Prometheus Query Language): a `rate()` of a counter, an error ratio built from two sums, and a `histogram_quantile()` over histogram buckets.

Your playground is a single-node `kind` cluster running Kubernetes 1.35, with a trimmed Prometheus stack in the namespace `monitoring`: the Prometheus Operator, one Prometheus server (version 3.15.0, Service `kps-prometheus` on port `9090`) and Grafana 13.2.3 (Service `kps-grafana` on port `80`). Alertmanager and the exporters for node and Kubernetes object metrics are disabled. Grafana has no data source and no dashboard yet; the default data source and default dashboards are switched off.

| Namespace | Workload | What it is |
| --- | --- | --- |
| `starfleet` | `scout` | Two pods of `podinfo` 6.15.0, scraped by a ServiceMonitor |
| `starfleet` | `shuttle` | A client pod that sends normal requests to each `scout`, plus a `/status/500` every fifth loop and a `/delay/1` every tenth loop to the `starfleet` `scout` |
| `outpost` | `scout` | One pod of `podinfo` 6.15.0, scraped by a ServiceMonitor. It only gets normal requests |

A namespace groups Kubernetes resources. A ServiceMonitor tells the Prometheus Operator which Service endpoints to scrape; both monitors carry the selected label `release: kps`. The Grafana user is `admin` with the password `starfleet`. Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

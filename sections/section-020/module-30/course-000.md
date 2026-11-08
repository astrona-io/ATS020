# Query Logs With Loki And LogQL

Logs on a node disappear with their Pods, and searching many Pods one at a time with `kubectl logs` is slow during an incident. **Loki** is a log store that keeps lines from many Pods in one place and indexes only their labels. **LogQL** is its query language. A **label** is a name and value attached to log lines, such as `namespace="outpost"`. You will read logs from Grafana and from the API, and use one query result to stop the workloads that fail.

The module has three parts. **Connect Grafana To Loki** adds a Loki data source in the web interface and through the API and changes its **Maximum lines** setting. **Query Logs With LogQL** selects streams, filters lines and turns lines into numbers. **Edit A Panel And Act On The Result** saves a corrected panel query, shows how long that edit lasts, and scales down the controllers behind the failing Pods. The summary closes the module.

## Learning objectives

After this module you can:

- Add and inspect a Loki data source in Grafana, and change `jsonData.maxLines` in the web interface and through the API.
- Write LogQL stream selectors and line filters such as `|= "ERROR"`.
- Write metric queries such as `count(rate({namespace="outpost"} |= "ERROR" [5m]))` and say what they count.
- Edit a dashboard panel's query, save it, and explain why that edit differs from a dashboard kept as code.
- Use a query result to find the Pods that write errors and scale their controllers to `0`.

## Before you start

You need `kubectl get`, `scale` and `port-forward`, `curl`, basic `jq`, and the idea of a **Grafana dashboard**, a set of panels that each run a query against a **data source**, the connection Grafana uses to read data. A **controller** is a Kubernetes object that keeps Pods running, such as a Deployment or a StatefulSet.

The playground runs Kubernetes 1.35.8, Grafana 13.2.3 and Loki 3.7.9. An OpenTelemetry Collector DaemonSet in `logging` sends the logs of `outpost` and `starfleet` to Loki. It is plumbing and needs no attention. `outpost` holds the Deployments `probe`, `beacon` and `scout` and the StatefulSet `depot`. `starfleet` holds the Deployments `relay` and `shuttle`. Grafana has a saved dashboard named `Outpost Logs`, and no data source yet. Its user is `admin` and its password is `starfleet`.

Write the example files in an empty working folder.

<!-- astrona:playground -->

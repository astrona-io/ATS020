# Summary

Grafana draws query results from a data source, a connection to a backend such as Prometheus. A fixed unique identifier (UID) lets dashboard panels use the same connection after deployment to a new cluster. The data source address must be reachable from the Grafana server, so a Kubernetes Service address belongs in the provisioning file. A local port-forward gives your browser access to Grafana.

A dashboard holds panels and their queries. Prometheus Query Language (PromQL) calculates request rates, error ratios and latency estimates from application metrics. Time series panels show changes over time; a stat panel highlights one number. A fractional error ratio needs the `percentunit` unit. Histogram percentiles estimate boundaries from buckets and do not report the longest individual request.

A query variable fills a drop-down list from metric labels. Grafana substitutes the selected namespace into every panel query before sending it to Prometheus. An empty error series makes a ratio empty, rather than zero, so check both sides of a division when a panel shows no data.

Provisioning loads data sources and dashboards from files. The playground's sidecars copy ConfigMaps with the selected labels into Grafana's provisioning directories. Export only the dashboard model, retain stable UIDs, and store the JavaScript Object Notation (JSON) document in a labelled ConfigMap. The dashboard and its data source then return when Grafana starts in a new pod.

Temporary pod storage loses the Grafana database when the pod is replaced. Persistent storage can retain that database, but keeping dashboard files under version control also makes changes reviewable and repeatable. Prove recovery by checking the restored dashboard and a working data source query after the replacement.

<!-- astrona:playground:destroy -->

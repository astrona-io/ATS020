# Summary

Prometheus only collects what it is told to collect. The Prometheus Operator can generate its configuration from monitor resources, or a directly managed server can read scrape jobs from a file. Both styles connect workload endpoints to Prometheus and provide ways to find why a target is missing.

## What you learned

Prometheus scrapes: on a fixed interval it sends an HTTP `GET` to each target's metrics endpoint and stores what it reads. Each target gets an `up` series, `1` after a working scrape and `0` after a failed one. The targets list and the `up` metric give the same facts, one for reading and one for querying. No `up` series at all means Prometheus never tried that endpoint.

A ServiceMonitor selects Services by label, and the operator follows each Service to its endpoints and scrapes the named Service port and path. A PodMonitor selects pods directly and names a container port, for workloads without a Service. A ServiceMonitor's targets get the Service name as their `job`, and a PodMonitor's targets get `<namespace>/<name>`. Both look only in their own namespace unless `namespaceSelector` says otherwise.

The Prometheus resource reads only the monitors its own selectors match. With the `kube-prometheus-stack` chart's defaults, that means monitors with the label `release: <release name>`, here `release: kps`. A monitor without that label is ignored with no error and no status. A change to a monitor takes about a minute to reach Prometheus, because the generated configuration travels through a mounted Secret.

Mistakes in how to scrape, such as a wrong path, leave a target that is `down` with an error you can read. Mistakes in what to scrape, such as a wrong selector label or port name, leave no target at all; the running configuration shows whether the job exists, and the dropped targets show the port names Prometheus really saw. The key facts to remember are these:

- Read `serviceMonitorSelector` and `podMonitorSelector` before you write a monitor.
- `endpoints[].port` is a Service port name; `podMetricsEndpoints[].port` is a container port name.
- A target that is `down` has a last error; a target that is missing needs the chain walked.
- The proof of a working scrape is one `up == 1` series per endpoint of the workload.

Raw configuration uses `kubernetes_sd_configs` to discover Pods and `relabel_configs` to filter targets and copy labels. An `action: keep` rule accepts only targets that match its expression. Extend that expression to include another label value without collecting disabled workloads. Apply the ConfigMap, then restart Prometheus or reload it after the mounted file updates. Check the running configuration and target list before trusting a query.

A `sum by (deployment)` query combines per-Pod gauge values into workload totals. Compare all selected workloads before choosing which Deployment to scale, then check its ready replicas. Operator resources suit a controller-managed server; raw scrape jobs suit a server managed directly from a configuration file.

<!-- astrona:playground:destroy -->

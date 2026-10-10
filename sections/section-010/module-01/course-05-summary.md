# Summary

Prometheus only collects what it is told to collect, and on Kubernetes the Prometheus Operator decides that from monitor resources. This module showed how those resources connect a workload to Prometheus and how to tell why a workload is missing.

## What you learned

Prometheus scrapes: on a fixed interval it sends an HTTP `GET` to each target's metrics endpoint and stores what it reads. Each target gets an `up` series, `1` after a working scrape and `0` after a failed one. The targets list and the `up` metric give the same facts, one for reading and one for querying. No `up` series at all means Prometheus never tried that endpoint.

A ServiceMonitor selects Services by label, and the operator follows each Service to its endpoints and scrapes the named Service port and path. A PodMonitor selects pods directly and names a container port, for workloads without a Service. A ServiceMonitor's targets get the Service name as their `job`, and a PodMonitor's targets get `<namespace>/<name>`. Both look only in their own namespace unless `namespaceSelector` says otherwise.

The Prometheus resource reads only the monitors its own selectors match. With the `kube-prometheus-stack` chart's defaults, that means monitors with the label `release: <release name>`, here `release: kps`. A monitor without that label is ignored with no error and no status. A change to a monitor takes about a minute to reach Prometheus, because the generated configuration travels through a mounted Secret.

Mistakes in how to scrape, such as a wrong path, leave a target that is `down` with an error you can read. Mistakes in what to scrape, such as a wrong selector label or port name, leave no target at all; the running configuration shows whether the job exists, and the dropped targets show the port names Prometheus really saw. The key facts to remember are these:

- Read `serviceMonitorSelector` and `podMonitorSelector` before you write a monitor.
- `endpoints[].port` is a Service port name; `podMetricsEndpoints[].port` is a container port name.
- A target that is `down` has a last error; a target that is missing needs the chain walked.
- The proof of a working scrape is one `up == 1` series per endpoint of the workload.

<!-- astrona:playground:destroy -->

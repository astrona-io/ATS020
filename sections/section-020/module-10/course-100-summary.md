# Summary

Use the result of each lab as evidence that the corresponding operation works. A configuration accepted by Kubernetes is only the starting point; inspect the running component and the data or requests it produces.

| Outcome | Evidence checked by the lab |
| --- | --- |
| Provision The Prometheus Data Source | The Scout Overview dashboard is loaded from a labelled ConfigMap and Grafana reports it as provisioned; All three panels exist and every panel query returns data through its own data source; The data source the panels use is provisioned from a ConfigMap, not created by hand |
| Repair Dashboard Data Source References | The Scout Overview dashboard is loaded from a labelled ConfigMap and Grafana reports it as provisioned; All three panels exist and every panel query returns data through its own data source; The data source the panels use is provisioned from a ConfigMap, not created by hand |
| Restore Dashboard Provisioning | The Scout Overview dashboard is loaded from a labelled ConfigMap and Grafana reports it as provisioned; All three panels exist and every panel query returns data through its own data source; The data source the panels use is provisioned from a ConfigMap, not created by hand |
| Restore Grafana Writable Storage | The Deployment grafana in telemetry has one ready replica and its health endpoint reports the database as ok; The Secret grafana-admin holds the key admin-password and the user admin signs in with the password starfleet; Image, environment names, probes and Service are unchanged; the data directory is not a ConfigMap; the memory limit is at least 256Mi |
| Repair Grafana Secret Keys | The Deployment grafana in telemetry has one ready replica and its health endpoint reports the database as ok; The Secret grafana-admin holds the key admin-password and the user admin signs in with the password starfleet; Image, environment names, probes and Service are unchanged; the data directory is not a ConfigMap; the memory limit is at least 256Mi |
| Size Grafana Memory For Startup | The Deployment grafana in telemetry has one ready replica and its health endpoint reports the database as ok; The Secret grafana-admin holds the key admin-password and the user admin signs in with the password starfleet; Image, environment names, probes and Service are unchanged; the data directory is not a ConfigMap; the memory limit is at least 256Mi |

If a result is missing, follow the same order used in the lessons: verify the source, inspect the selection or configuration, wait for reconciliation, and check fresh evidence. Retry the relevant independent lab when you need more practice. The section capstone combines these operations into a broader task.

Remove any completed lab environment. The playground can now be released:

<!-- astrona:playground:destroy -->

# Summary

Kubernetes keeps the stdout and stderr of every container in files on the node. `kubectl logs` reads the current container, `--previous` reads the container that exited, and `kubectl events` shows what Kubernetes did to the pod. These tools read one pod at a time and lose their data when a container or pod is removed, so a platform needs a pipeline that reads the files as they are written and keeps the result somewhere that lasts.

Container logs live under `/var/log/pods/<namespace>_<pod>_<uid>/<container>/` on each node, in the Container Runtime Interface format: a timestamp, a stream name, a flag and the line. Each node has its own files, so a DaemonSet runs one OpenTelemetry Collector pod per node. The Collector mounts the directory with a read-only `hostPath` volume. Its `file_log` receiver reads the files, and the `container` operator parses the format and sets the namespace, pod, container and pod UID as resource attributes. A Collector must exclude its own log files, and it starts at the end of each file unless told otherwise.

Processors change records in the order they are listed. The `k8s_attributes` processor adds data such as the Deployment and node name. It needs a `pod_association` rule on the pod UID and read access to pods. Without access, the Collector's log shows `pods is forbidden`, and the fix is a ClusterRole with `get`, `list` and `watch` on `pods`, bound to the Collector's service account. A broader role such as `cluster-admin` is not needed and is not safe. The `filter` processor drops records that match an expression, such as `level=INFO`.

The count connector ends a logs pipeline and starts a metrics pipeline. It counts the records that match a condition. The `delta_to_cumulative` processor turns its delta values into a growing counter, and the `prometheus` exporter serves the counter on a port. Resource attributes become labels with underscores, such as `k8s_deployment_name`. A ServiceMonitor with the label that the Prometheus resource selects, and a selector that matches the Collector's metric Service, makes Prometheus scrape it. The proof is a target with `up == 1` and a query such as `rate(log_error_lines_total[1m])` that returns a value for the right Deployment.

Key facts:

- The receiver is `file_log`, the processor is `k8s_attributes`, and the older names `filelog` and `k8sattributes` still work in version 0.162.0 with a deprecation warning.
- Records from files need `pod_association` on `k8s.pod.uid` before `k8s_attributes` adds anything.
- The count connector needs `delta_to_cumulative` before the Prometheus exporter, or the counter stays at 1.
- A ServiceMonitor that Prometheus does not select shows no target at all.

<!-- astrona:playground:destroy -->

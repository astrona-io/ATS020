# Add Kubernetes Metadata And Drop Records

A log record that says only `level=ERROR` and a pod name is hard to use. People ask which Deployment failed and on which node, and most lines are routine `INFO` messages that nobody needs. This part adds the Deployment and node name with the `k8s_attributes` processor, which needs permission to read pods. It then removes the `INFO` lines with the `filter` processor.

## Add the Deployment name

The `k8s_attributes` processor asks the Kubernetes API server for the pod that wrote each record. It copies data from that pod, such as the name of its Deployment and node, into the resource attributes of the record. It reads pods through a watch, so it holds a list of all pods in memory and does not call the API server for each record.

The processor must know which pod a record belongs to. The `container` operator already set the resource attribute `k8s.pod.uid`. The setting `pod_association` tells the processor to match on it. Without `pod_association`, records that come from files get no extra data. The setting `filter.node_from_env_var` limits the watch to pods on the Collector's own node. The variable `K8S_NODE_NAME` comes from the field `spec.nodeName` of the pod through the `env` field.

The `filter` processor drops records that match a condition. The condition is written in the OpenTelemetry Transformation Language (OTTL). The expression `IsMatch(body, "level=INFO")` is true when the body contains `level=INFO`. The setting `error_mode: ignore` skips a record when the expression fails, instead of stopping the pipeline.

<!-- astrona:playground:renew -->

Save this as `collector-logs-metadata.yaml`. It replaces the earlier Collector, so the debug exporter stays and two processors join the pipeline:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: logs
  namespace: monitoring
spec:
  mode: daemonset
  image: otel/opentelemetry-collector-contrib:0.165.0
  env:
    - name: K8S_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
  volumes:
    - name: varlogpods
      hostPath:
        path: /var/log/pods
  volumeMounts:
    - name: varlogpods
      mountPath: /var/log/pods
      readOnly: true
  config:
    receivers:
      file_log:
        include:
          - /var/log/pods/*/*/*.log
        exclude:
          - /var/log/pods/monitoring_logs-collector-*/*/*.log
        start_at: end
        include_file_path: true
        operators:
          - type: container
    processors:
      k8s_attributes:
        filter:
          node_from_env_var: K8S_NODE_NAME
        pod_association:
          - sources:
              - from: resource_attribute
                name: k8s.pod.uid
        extract:
          metadata:
            - k8s.deployment.name
            - k8s.node.name
      filter/drop-info:
        error_mode: ignore
        logs:
          log_record:
            - 'IsMatch(body, "level=INFO")'
    exporters:
      debug:
        verbosity: detailed
    service:
      pipelines:
        logs:
          receivers: [file_log]
          processors: [k8s_attributes, filter/drop-info]
          exporters: [debug]
```

The processors run in the order of the list: first `k8s_attributes`, then `filter/drop-info`. Apply it:

```sh
kubectl apply -f collector-logs-metadata.yaml
```

The operator replaces the Collector pod. The `k8s_attributes` processor has no permission yet, and that is the next thing to see.

## Read the permission error

The Collector's pod runs as the service account `logs-collector`, which the operator created. A new service account can read nothing in the Kubernetes API. Wait about 20 seconds and search the Collector's log for the error:

```sh
kubectl -n monitoring logs ds/logs-collector | grep -i forbidden | head -1 | cut -c1-260
```

You should see:

```text
E1102 19:37:01.451715       1 reflector.go:227] "Failed to watch" err="failed to list *v1.Pod: pods is forbidden: User \"system:serviceaccount:monitoring:logs-collector\" cannot list resource \"pods\" in API group \"\" at the cluster scope" logger="UnhandledEr
```

The message says who (`system:serviceaccount:monitoring:logs-collector`), what it cannot do (`list` the resource `pods`) and where (`at the cluster scope`). Meanwhile the records still flow, but they carry only the attributes from the `container` operator. The processor does not stop the pipeline when it cannot read pods.

## Grant read access to pods

The fix is a **ClusterRole**, a list of allowed actions on resources in the whole cluster, and a **ClusterRoleBinding**, which gives that role to a service account. The processor needs three verbs on one resource: `get`, `list` and `watch` on `pods`. Nothing more is needed, because the processor takes the Deployment name from the owner of the pod. Do not bind `cluster-admin` here. A log Collector that can read pods does not need to read secrets or change anything.

Save this as `clusterrole-logs-collector.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: logs-collector
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

Save this as `clusterrolebinding-logs-collector.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: logs-collector
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: logs-collector
subjects:
  - kind: ServiceAccount
    name: logs-collector
    namespace: monitoring
```

Apply both:

```sh
kubectl apply -f clusterrole-logs-collector.yaml -f clusterrolebinding-logs-collector.yaml
```

Then check the result with `kubectl auth can-i`, which asks the API server whether a user may do an action. The flag `--as` makes the question about the service account:

```sh
kubectl auth can-i list pods --as=system:serviceaccount:monitoring:logs-collector
kubectl auth can-i get secrets --as=system:serviceaccount:monitoring:logs-collector
```

You should see:

```text
yes
no
```

## See the new attributes and the filter

The processor recovers by itself in about 30 seconds, so the Collector pod does not need a restart. Look at the newest log record:

```sh
kubectl -n monitoring logs ds/logs-collector --tail=40 | grep -E "^\s+-> k8s\.|^Body" | tail -8 | cut -c1-150
```

You should see the two new resource attributes, `k8s.deployment.name` and `k8s.node.name`, and a `Body` with `level=ERROR`. The output below is shortened to the lines that matter:

```text
     -> k8s.namespace.name: Str(outpost)
     -> k8s.pod.name: Str(probe-7749f6b9bc-gkdm6)
     -> k8s.container.restart_count: Str(0)
     -> k8s.deployment.name: Str(probe)
     -> k8s.node.name: Str(astro-ats-020-playground-020-02-control-plane)
Body: Str(time=2026-11-02T19:37:35.335Z level=ERROR msg="500 GET /status/500 0.1ms" status=500 ...)
```

The filter works too. Count the records of the last 20 seconds by level. The two numbers below come from one run; the exact count of `ERROR` lines depends on timing:

```sh
kubectl -n monitoring logs ds/logs-collector --since=20s | grep -c "^Body: Str(.*level=INFO"
kubectl -n monitoring logs ds/logs-collector --since=20s | grep -c "^Body: Str(.*level=ERROR"
```

You should see:

```text
0
5
```

No `INFO` record reached the exporter, and the `ERROR` records of `probe` did. The filter keeps the later steps small: only the lines you care about leave the Collector.

You now know how to give each log record the Deployment and node name, how to read a permission error in the Collector's log, and how to grant the minimum access that fixes it. Records now carry the data you need to count them per Deployment. The open question is how to turn these records into a number that Prometheus can store and alert on.

## Common pitfalls

> [!WARNING]
> - **No `pod_association`.** The processor starts without an error and adds nothing for file-based records. Associate by `k8s.pod.uid`.
> - **Fixing the error with `cluster-admin`.** The processor needs `get`, `list` and `watch` on `pods` only. A broad role gives a log reader the power to change the cluster.
> - **Waiting for a restart.** The processor retries on its own. Check the log again after about 30 seconds before you restart anything.
> - **Filtering on a namespace that is silent.** The `starfleet` pods write almost no log lines, so a filter on that namespace would show no change. Check which pods really log before you choose a condition.

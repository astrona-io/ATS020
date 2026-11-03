# Solution

Work in order. After each step run `astrona submit` and read which checks still fail. A new ServiceMonitor reaches Prometheus after about a minute, so wait before you decide a fix did not work.

## Step 1: Permission and Collector

The Collector reads pods to add the Deployment name, so its service account needs `get`, `list` and `watch` on pods. Save the file as `logs-collector.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: logs-collector
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
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
---
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: logs
  namespace: monitoring
spec:
  mode: daemonset
  image: otel/opentelemetry-collector-contrib:0.162.0
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
      delta_to_cumulative: {}
    connectors:
      count:
        logs:
          log_error_lines:
            description: Log lines with level=ERROR
            conditions:
              - 'IsMatch(body, "level=ERROR")'
    exporters:
      debug:
        verbosity: basic
      prometheus:
        endpoint: 0.0.0.0:8889
        resource_to_telemetry_conversion:
          enabled: true
    service:
      pipelines:
        logs:
          receivers: [file_log]
          processors: [k8s_attributes, filter/drop-info]
          exporters: [debug, count]
        metrics:
          receivers: [count]
          processors: [delta_to_cumulative]
          exporters: [prometheus]
```

Apply the file and check the pods:

```sh
kubectl apply -f logs-collector.yaml
kubectl -n monitoring rollout status daemonset/logs-collector
```

## Step 2: ServiceMonitor

Prometheus selects only ServiceMonitors with the label `release: kps`. Save the file as `servicemonitor-logs-collector.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: logs-collector
  namespace: monitoring
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: monitoring.logs
      operator.opentelemetry.io/collector-service-type: base
  endpoints:
    - port: prometheus
      interval: 15s
```

Apply it, wait about a minute, and open the Prometheus targets page:

```sh
kubectl apply -f servicemonitor-logs-collector.yaml
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Open `http://localhost:9090/targets`. The target on port `8889` must be `UP`.

## Step 3: Dashboard

The ConfigMap `dashboard-outpost-overview` has two faults:

1. It has no label `grafana_dashboard: "1"`, so the Grafana sidecar ignores it. Add the label.
2. The panel `Error log lines` filters on `k8s_deploy="probe"`. The label that the Collector adds is `k8s_deployment_name`. Change the expression to use `k8s_deployment_name="probe"`.

Apply the corrected ConfigMap and wait a few seconds. Run `astrona submit`. All six checks must pass.

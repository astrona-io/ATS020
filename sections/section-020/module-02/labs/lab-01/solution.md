# Solution

This walkthrough finds why `log_error_lines_total` is missing its `probe` labels in Prometheus, and fixes both faults. A DaemonSet is a workload that runs one pod on every node. Here that pod is the Collector, which reads the container log files and exports a metric. Run each step.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-020/module-02/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Step 1: Look at what exists

Start by listing the Collector and the ServiceMonitors in `monitoring`:

```sh
kubectl -n monitoring get opentelemetrycollector,servicemonitor
```

You should see:

```text
NAME                                           MODE        VERSION   READY   AGE     IMAGE                                          MANAGEMENT
opentelemetrycollector.opentelemetry.io/logs   daemonset   0.160.0   1/1     6m28s   otel/opentelemetry-collector-contrib:0.162.0   managed

NAME                                                  AGE
servicemonitor.monitoring.coreos.com/kps-operator     6m45s
servicemonitor.monitoring.coreos.com/kps-prometheus   6m45s
servicemonitor.monitoring.coreos.com/logs-collector   6m28s
```

The Collector runs and is ready, so the fault is not a crashed pod. The ServiceMonitor `logs-collector` exists as well. The checks that remain are what the Collector says in its own logs, and what Prometheus does with the ServiceMonitor.

## Step 2: Read the Collector's logs

The Collector writes its own errors to standard error. Search them for a permission problem:

```sh
kubectl -n monitoring logs daemonset/logs-collector --tail=200 | grep -m1 forbidden
```

You should see a line like this (shortened):

```text
E1102 19:18:35.377252       1 reflector.go:227] "Failed to watch" err="failed to list *v1.Pod: pods is forbidden: User \"system:serviceaccount:monitoring:logs-collector\" cannot list resource \"pods\" in API group \"\" at the cluster scope"
```

The `k8s_attributes` processor needs to list and watch pods to add the deployment name to each log record. The service account `logs-collector` in `monitoring` has no such permission. The ClusterRole `logs-collector` already allows `get`, `list` and `watch` on pods, but nothing binds it to the service account: `kubectl get clusterrolebinding | grep logs-collector` prints nothing.

## Step 3: Bind the ClusterRole

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

Apply it:

```sh
kubectl apply -f clusterrolebinding-logs-collector.yaml
```

Then check the result:

```sh
kubectl auth can-i list pods --all-namespaces --as=system:serviceaccount:monitoring:logs-collector
```

You should see:

```text
yes
```

The Collector does not need a restart. Its processor retries, and the errors stop within about 30 seconds. Do not bind `cluster-admin` here: the grader rejects a service account that can read secrets or change pods.

## Step 4: Find out why Prometheus has no target

Open a port-forward to Prometheus in another terminal:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

List the scrape jobs Prometheus knows:

```sh
curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[].labels.job' | sort | uniq -c
```

You should see:

```text
   1 kps-operator
   2 kps-prometheus
```

There is no `logs-collector` job. The Prometheus resource only selects ServiceMonitors that carry a given label. Compare it with the labels of the ServiceMonitor:

```sh
kubectl -n monitoring get prometheus kps-prometheus -o jsonpath='{.spec.serviceMonitorSelector}{"\n"}'
kubectl -n monitoring get servicemonitor logs-collector --show-labels
```

You should see:

```text
{"matchLabels":{"release":"kps"}}
NAME             AGE     LABELS
logs-collector   6m28s   <none>
```

The selector asks for `release: kps` and the ServiceMonitor has no labels.

## Step 5: Label the ServiceMonitor

Add the label:

```sh
kubectl -n monitoring label servicemonitor logs-collector release=kps
```

You should see:

```text
servicemonitor.monitoring.coreos.com/logs-collector labeled
```

Prometheus reads the change after about a minute.

## Step 6: Prove it with a query

Check that the target is up:

```sh
curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="logs-collector") | "\(.labels.job) \(.health)"'
```

You should see:

```text
logs-collector up
```

Then run the query twice, about 30 seconds apart:

```sh
curl -s localhost:9090/api/v1/query --data-urlencode 'query=sum by (k8s_namespace_name, k8s_deployment_name) (log_error_lines_total{k8s_deployment_name="probe"})' | jq -c '.data.result[]'
```

You should see a value that rises. Your numbers will differ:

```text
{"metric":{"k8s_deployment_name":"probe","k8s_namespace_name":"outpost"},"value":[1793647611.776,"16"]}
{"metric":{"k8s_deployment_name":"probe","k8s_namespace_name":"outpost"},"value":[1793647641.806,"24"]}
```

The value grows by about 8 in 30 seconds, because `probe` logs one `level=ERROR` line every 4 seconds. The labels `k8s_namespace_name` and `k8s_deployment_name` are there because the `k8s_attributes` processor can read pods now.

The watch terminal shows the checks passing. Press Ctrl-C to stop the watch, then submit once:

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

## Wrong fixes the grader rejects

- Binding `cluster-admin` to the service account. The metric works, but the Collector can read secrets.
- Removing `k8s_attributes` from the pipeline. The permission errors stop, but the deployment label never appears.
- Editing the metric or the query by hand. The grader reads the series in Prometheus and checks that it keeps rising.

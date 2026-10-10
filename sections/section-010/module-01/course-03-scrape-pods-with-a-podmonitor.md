# Scrape Pods Without A Service With A PodMonitor

Not every workload has a Service. A batch worker, a queue consumer or an agent on every node may serve metrics without taking any traffic, so nobody created a Service for it. A ServiceMonitor cannot reach such pods, because it follows Services. This part collects the `scout` pod in `outpost`, which has no Service, with a PodMonitor.

## How a PodMonitor differs

A **PodMonitor** is the Prometheus Operator's resource for scraping pods directly. It has the same shape as a ServiceMonitor with one step removed: its label selector matches pods, and each entry under `podMetricsEndpoints` names a **container port** of those pods. There is no Service and no endpoints list in between.

The Prometheus resource reads PodMonitors through its own pair of selectors, `podMonitorSelector` and `podMonitorNamespaceSelector`. In this playground they are set the same way as the ServiceMonitor selectors: every namespace, and only monitors with the label `release: kps`.

Choose a PodMonitor when the pods have no Service, or when the Service exposes a different port than the one with the metrics and you do not want to add a port to the Service. Choose a ServiceMonitor when a Service already exists, because the Service's selector then decides which pods count, in one place.

## Check what the pods offer

The PodMonitor names a container port, so check the port's name first:

<!-- astrona:playground:renew -->

```sh
kubectl -n outpost get pods -l app=scout -o jsonpath='{.items[*].spec.containers[*].ports}'
```

You should see:

```text
[{"containerPort":9898,"name":"http","protocol":"TCP"}]
```

The container port is named `http`, and the pods carry the label `app: scout`. That is all the PodMonitor needs.

## Write the PodMonitor

Save this as `podmonitor-scout.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: scout
  namespace: outpost
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app: scout
  podMetricsEndpoints:
    - port: http
      path: /metrics
      interval: 15s
```

The label `release: kps` makes the Prometheus resource read it. `spec.selector` matches the pods, and `podMetricsEndpoints[].port` is the name of the container port. Like a ServiceMonitor, a PodMonitor only looks in its own namespace unless `spec.namespaceSelector` says otherwise.

Apply it:

```sh
kubectl apply -f podmonitor-scout.yaml
```

Wait about a minute for the new configuration to reach Prometheus, then check:

```sh
show_targets
query_up '{namespace="outpost"}'
```

You should see something like:

```text
outpost/scout	http://10.244.0.12:9898/metrics	up
kps-operator	https://10.244.0.6:10250/metrics	up
kps-prometheus	http://10.244.0.7:9090/metrics	up
kps-prometheus	http://10.244.0.7:8080/metrics	up
scout	http://10.244.0.10:9898/metrics	up
scout	http://10.244.0.9:9898/metrics	up
outpost/scout	scout-674cfb4855-9vsgz	1
```

The `outpost` pod is now a target, and its `up` series is `1`. Look at the `job` label: it is `outpost/scout`, the namespace and the name of the PodMonitor, while the ServiceMonitor's targets got `scout`, the Service name. Queries that filter on `job` must use the right form, so it is often easier to filter on `namespace` and `pod`.

The operator wrote a job for the PodMonitor too. It appears in the running configuration as `podMonitor/outpost/scout/0`, next to the `serviceMonitor/...` jobs.

You can now collect metrics from pods with or without a Service, and you know how the two kinds of monitor label their targets. Both monitors worked on the first try here. The open question is what you see when a monitor is wrong in a way that is harder to spot than a missing label.

## Common pitfalls

> [!WARNING]
> - **Using a Service port name in a PodMonitor.** `podMetricsEndpoints[].port` is the name of a container port in the pod spec.
> - **Expecting the same `job` label from both kinds of monitor.** A ServiceMonitor's targets take the Service name; a PodMonitor's targets take `<namespace>/<podmonitor name>`.
> - **Scraping the same pods with a ServiceMonitor and a PodMonitor.** Every sample is then stored twice under two jobs, and sums over the workload double.
> - **Forgetting the selector label on a PodMonitor.** It needs the label that `podMonitorSelector` matches, just like a ServiceMonitor.

# Scrape Pods With Raw Prometheus Configuration

The `probe` Deployment exposes metrics, but Prometheus never requests them.
There is no Prometheus Operator to read a PodMonitor. Instead, this server
reads `prometheus.yml` from a ConfigMap, a Kubernetes object that holds
configuration text. To add the missing Pods, you must change the file and
make Prometheus load it before using its data to choose a scaling action.

## Read the file Prometheus actually uses

Use the dedicated lab environment for these commands. It runs plain
Prometheus 3.15.0 without an Operator. Pause the playground and start the lab;
its task is on the next page. This avoids adding another Prometheus server
to the playground cluster.

<!-- astrona:playground:renew -->

```sh
astrona stop ats-020-playground-010-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-01/labs/lab-02
```

The namespace `monitoring` contains the Deployment and Service
`prometheus-raw`. A Deployment keeps a chosen number of Pods running. Each
Pod is a group of containers that share a network address. Read the
Deployment arguments and its ConfigMap:

```sh
kubectl -n monitoring get deployment prometheus-raw -o yaml
kubectl -n monitoring get configmap prometheus-raw -o jsonpath='{.data.prometheus\.yml}'
kubectl -n starfleet get pods -L app,telemetry
```

Find `--config.file=/etc/prometheus/prometheus.yml` and the volume mounted at
`/etc/prometheus`. They connect the process to the ConfigMap key
`prometheus.yml`. The job `starfleet-pods` uses `kubernetes_sd_configs` for
Kubernetes service discovery: Prometheus asks the Kubernetes application
programming interface (API) for Pods, then keeps its target list updated as
Pods change. A service account is the identity a Pod uses with the Kubernetes API.
The Prometheus service account has permission to get, list and watch Pods
in `starfleet`; discovery needs those permissions even when scraping works
without authentication.

A target is one endpoint Prometheus scrapes. A scrape is an HTTP
(Hypertext Transfer Protocol) request for metrics. With `role: pod`, discovery
creates a candidate target for each declared container port. The discovered
labels beginning with `__meta_kubernetes_` describe the Pod and its port.
They are temporary metadata, not labels automatically stored on every metric.

## Extend one keep rule

The first `relabel_configs` rule uses `action: keep`: Prometheus discards a
candidate unless its selected label matches the regular expression. A
regular expression describes which text values match. The current
`regex: primary` accepts `scout` but drops `probe`, whose Pod label is
`telemetry: reserve`. The rule must accept both values while still excluding
`telemetry: disabled` on `shuttle`.

Save this as `configmap-prometheus-raw.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-raw
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 5s
      scrape_timeout: 4s
    scrape_configs:
      - job_name: starfleet-pods
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: [starfleet]
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_telemetry]
            action: keep
            regex: primary|reserve
          - source_labels: [__meta_kubernetes_pod_container_port_name]
            action: keep
            regex: metrics
          - source_labels: [__meta_kubernetes_pod_ready]
            action: keep
            regex: 'true'
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_label_app]
            target_label: deployment
```

Apply it:

```sh
kubectl apply -f configmap-prometheus-raw.yaml
```

The `|` in `primary|reserve` accepts either value. Prometheus anchors this
match at both ends, so it accepts the full values, not longer strings that
contain them. Keep the port and readiness rules: they prevent scraping an
unrelated port or an unready Pod. Multiple keep rules filter in sequence;
adding another keep rule for `reserve` would require a Pod to match both
values and would drop both workloads.

The final three rules copy metadata into `namespace`, `pod` and `deployment`.
Their default action is `replace`. The `deployment` value comes from this
fixture's `app` label, whose value matches its Deployment name. Discovery
does not infer Deployment ownership from that label. Labels starting with
`__` disappear after target relabeling, so copy the metadata you need for
queries before that happens.

## Load the change and compare the targets

Applying a ConfigMap changes the Kubernetes object; it does not tell
Prometheus to read the file again. The simplest route here is to restart its
Deployment. A new Pod mounts the changed file before Prometheus starts:

```sh
kubectl -n monitoring rollout restart deployment/prometheus-raw
kubectl -n monitoring rollout status deployment/prometheus-raw --timeout=180s
kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/status/config' | jq -r '.data.yaml'
kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/targets?state=active' | jq '.data.activeTargets[] | {labels, health, lastError}'
```

Look for `primary|reserve` in the running configuration. Then look for a
healthy target for each ready `scout` and `probe` Pod, and no `shuttle` target.
Discovery and the first scrape take time, so retry if a new target is absent.
This lab stores metrics in an `emptyDir`, a temporary Pod volume; replacing
the Prometheus Pod removes its old samples. Production installations usually
need persistent storage.

A reload can preserve the running process and its samples. This Deployment
sets `--web.enable-lifecycle`, which enables `POST /-/reload`. After a later
ConfigMap edit, wait for Kubernetes to update the mounted file, then request
a reload. A ConfigMap mounted with `subPath` does not receive those updates.
Forward the Service in a separate terminal and leave the command running:

```sh
kubectl -n monitoring port-forward service/prometheus-raw 9090:9090
```

With the lifecycle flag enabled, the alternative reload route is:

```sh
curl -fsS -X POST http://127.0.0.1:9090/-/reload
curl -fsS http://127.0.0.1:9090/api/v1/status/config | jq -r '.data.yaml'
```

Inspect the loaded configuration after reloading. A successful request can
still reload the old file if the mount has not updated yet. Prometheus
rejects an invalid new configuration and keeps the previous one. Without
the lifecycle flag, use a restart instead of the HTTP reload route.

## Query a workload total and act on it

Prometheus Query Language (PromQL) selects metrics and calculates results.
A time series is one metric name and label set with samples collected over
time. The fixture exposes `starfleet_queue_items`, a gauge whose value can
rise or fall. Run this query against the forwarded Service:

```sh
curl -fsSG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=sum by (deployment) (starfleet_queue_items{job="starfleet-pods",namespace="starfleet"})' | jq '.data.result'
```

`sum by (deployment)` adds the Pod values for each Deployment, keeping only
the grouping label. Read the Deployment name in `metric.deployment` and
compare the numbers in `value[1]`. Wait until both selected workloads appear;
a missing workload is not a zero queue. `shuttle` is outside this query's
selected population even though its fixture reports a larger queue.

The fixture assigns `probe` the larger per-Pod queue. After confirming that
its total is highest, add replicas:

```sh
kubectl -n starfleet scale deployment probe --replicas=3
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet get deployments scout probe shuttle
```

Look for three ready `probe` replicas and one ready replica on each other
Deployment. This synthetic gauge stays fixed per Pod; it teaches choosing an
action from a query, not a real queue draining model. In a real service,
verify that extra replicas can share the work, then measure the effect.

Use Operator resources when a Prometheus Operator manages the server:
ServiceMonitor selects Service endpoints and PodMonitor selects Pods, and
the controller generates and reloads Prometheus configuration. Use raw
`scrape_configs` when the server is managed directly from a file. Creating a
monitor resource has no effect without a controller configured to read it;
editing an Operator-generated file can be overwritten by its next update.
In either style, the running configuration and healthy targets prove what
Prometheus actually loaded, and the query supplies the evidence for an action.

## Common pitfalls

> [!WARNING]
> - **Removing the keep rule.** That collects disabled workloads too. Extend the accepted values instead.
> - **Adding a second keep rule for the new value.** Sequential keep rules require every match. Put alternative values in the same expression.
> - **Applying without loading.** Check the running configuration after a restart or reload, not only the ConfigMap.
> - **Reloading before the mount updates.** Wait and retry, or restart the Deployment to mount the new file.
> - **Choosing a winner before discovery finishes.** Compare both workload totals before scaling.

## Your mission: Extend Raw Prometheus Discovery And Scale A Workload

You can now extend a raw discovery job, load the file and compare workload
totals. Complete the task in the running lab and submit it:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-01/labs/lab-02
```

When finished, remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-010-01-02
astrona start ats-020-playground-010-01
```

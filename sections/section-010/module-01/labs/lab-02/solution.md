# Solution Walkthrough

Extend the Pod discovery filter, make Prometheus read the changed file, then
use its metric data to decide which Deployment to scale. A ConfigMap is a
Kubernetes object that holds configuration text. Prometheus reads that text
as `prometheus.yml` through a mounted directory.

| Goal | Where it lives | What to inspect |
| --- | --- | --- |
| Choose Pods | ConfigMap | `kubernetes_sd_configs` and `relabel_configs` |
| Confirm the loaded file | Prometheus | `/api/v1/status/config` |
| Compare workload totals | PromQL query | `sum by (deployment)` |
| Add capacity | Deployment | Desired and ready replicas |

## The feedback loop

Run grading from the host terminal where you started the lab:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-01/labs/lab-02
```

Before making changes, expect `targets-up` and `busiest-scaled` to fail:
reserve Pods are missing, and no Deployment has three replicas.

## Step 1: Read the starting configuration

Read the ConfigMap and the workload labels:

```sh
kubectl -n monitoring get configmap prometheus-raw -o jsonpath='{.data.prometheus\.yml}'
kubectl -n starfleet get pods -L app,telemetry
kubectl -n monitoring get deploy prometheus-raw -o yaml
```

Look for `regex: primary`, the port filter `metrics` and the ready-Pod filter.
The Deployment mounts the whole ConfigMap directory and uses
`--config.file=/etc/prometheus/prometheus.yml`. Its lifecycle flag allows an
HTTP (Hypertext Transfer Protocol) reload request. No check changes yet.

## Step 2: Extend the keep rule and load it

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

`global` sets the scrape interval and timeout. `scrape_configs` defines the
job. `kubernetes_sd_configs` discovers Pods only in `starfleet`. The first
keep rule accepts either label value; the next two keep only the named
metrics port on ready Pods. The final rules copy discovery metadata into
persistent target labels so that a query can group by `deployment`.

Apply it:

```sh
kubectl apply -f configmap-prometheus-raw.yaml
```

Restart the Deployment so a new Pod mounts the updated ConfigMap:

```sh
kubectl -n monitoring rollout restart deployment/prometheus-raw
kubectl -n monitoring rollout status deployment/prometheus-raw --timeout=180s
kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/status/config' | jq -r '.data.yaml'
kubectl get --raw '/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/targets?state=active' | jq '.data.activeTargets[] | {labels, health, lastError}'
```

Look for the extended regular expression in the loaded configuration and one
healthy target for each selected Pod. Wait for discovery and a scrape if a
target has not appeared yet. This restart replaces the lab's temporary data
volume, so wait for fresh samples before querying.

**Run the check:** rerun `astrona submit` from the host terminal.
`targets-up` should pass; `busiest-scaled` still needs the scaling step.

## Step 3: Query and scale the busiest workload

Forward the Service in a separate terminal and leave it running:

```sh
kubectl -n monitoring port-forward service/prometheus-raw 9090:9090
```

PromQL means Prometheus Query Language. Run this instant query, which returns
one total per Deployment at the current time:

```sh
curl -fsSG http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=sum by (deployment) (starfleet_queue_items{job="starfleet-pods",namespace="starfleet"})' | jq '.data.result'
```

Read `metric.deployment` and the numeric string in `value[1]` for both results.
The fixture assigns the larger per-Pod queue to `probe`, so it should have
the larger total while both Deployments have one replica. This is configured
sample data, not measured production demand. Scale `probe` only after the
query shows that result:

```sh
kubectl -n starfleet scale deployment probe --replicas=3
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet get deployments scout probe shuttle
```

Look for three ready `probe` replicas and one ready replica for each other
Deployment. The gauge stays fixed per Pod in this exercise; scaling does not
simulate draining a real queue. New Pods need discovery and a successful
scrape before the target list is complete.

**Run the check:** both checks should now pass:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-01/labs/lab-02
```

## If a check stays red

- **`targets-up`: reserve Pods are absent.** Check the loaded configuration,
  rather than just the ConfigMap. Restart after applying the saved file.
- **`targets-up`: disabled Pods appear.** Restore the keep rule with
  `primary|reserve`; do not remove filtering. Keep the port and readiness rules.
- **`busiest-scaled`: a workload total is missing.** Wait for both healthy
  targets and rerun the query before choosing a Deployment.
- **`busiest-scaled`: replicas differ.** Keep metric inputs and labels unchanged.
  The selected winner needs three ready replicas; the other Deployments need one.

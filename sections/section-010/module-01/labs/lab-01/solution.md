# Solution

Prometheus shows no `scout` target because of three separate mistakes in the ServiceMonitor `scout`. The first hides the whole object, the second drops every endpoint, and the third makes the target fail with an error. You find them in this order, because each one hides the next. Prometheus needs about a minute to read a changed monitor, so wait before each check.

Keep this command running in a second host terminal. It grades the lab every few seconds and records nothing:

```sh
astrona submit --watch -c sections/section-010/module-01/labs/lab-01
```

Use `--watch` until the end, because a plain `astrona submit` finishes the attempt and deletes the lab. Run the plain command once, in the last step.

## Find the first mistake

Open a second terminal and leave a port-forward to Prometheus running:

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

Define a helper that prints each active target with its health and last error:

```sh
show_targets() {
  curl -s http://127.0.0.1:9090/api/v1/targets |
    jq -r '.data.activeTargets[] | "\(.labels.job)\t\(.scrapeUrl)\t\(.health)\t\(.lastError)"'
}
```

Run it, then read the label the Prometheus resource selects and the labels of the ServiceMonitor:

```sh
show_targets
kubectl -n monitoring get prometheus kps-prometheus -o yaml | grep -A2 serviceMonitorSelector
kubectl -n starfleet get servicemonitors.monitoring.coreos.com scout --show-labels
```

```text
kps-operator	https://10.244.0.6:10250/metrics	up
kps-prometheus	http://10.244.0.7:9090/metrics	up
kps-prometheus	http://10.244.0.7:8080/metrics	up
  serviceMonitorSelector:
    matchLabels:
      release: kps
NAME    AGE   LABELS
scout   18m   release=prometheus
```

There is no `scout` target. The Prometheus resource reads only ServiceMonitors with the label `release: kps`, and this one has `release: prometheus`. Prometheus ignores the object and shows no error.

## Fix the label

Save this as `servicemonitor-scout.yaml`. It has the label fixed. The port and the path are still wrong on purpose:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: scout
  namespace: starfleet
  labels:
    release: kps
spec:
  selector:
    matchLabels:
      app: scout
  endpoints:
    - port: metrics
      path: /metric
      interval: 15s
```

Apply it:

```sh
kubectl apply -f servicemonitor-scout.yaml
```

Wait about a minute. The job now exists, but the targets list is still empty for `scout`. Ask for the dropped targets from `starfleet`:

```sh
curl -s 'http://127.0.0.1:9090/api/v1/targets?state=dropped' |
  jq -r '.data.droppedTargets[] | select(.discoveredLabels.__meta_kubernetes_namespace=="starfleet")
    | "\(.scrapePool)\t\(.discoveredLabels.__meta_kubernetes_pod_name)\t\(.discoveredLabels.__meta_kubernetes_endpoint_port_name)"'
```

```text
serviceMonitor/starfleet/scout/0	scout-674cfb4855-xcwdj	http
serviceMonitor/starfleet/scout/0	scout-674cfb4855-776xt	http
```

Prometheus found both pods and dropped them. The last column is the port name the Service really has, `http`. The ServiceMonitor asks for `metrics`.

## Fix the port name

Change `port: metrics` to `port: http` in `servicemonitor-scout.yaml` and apply the file again:

```sh
kubectl apply -f servicemonitor-scout.yaml
```

Wait about a minute, then list the targets and the `up` series:

```sh
show_targets
curl -s http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=up{namespace="starfleet"}' |
  jq -r '.data.result[] | "\(.metric.job)\t\(.metric.pod)\t\(.value[1])"'
```

```text
scout	http://10.244.0.9:9898/metric	down	server returned HTTP status 404 Not Found
scout	http://10.244.0.10:9898/metric	down	server returned HTTP status 404 Not Found
scout	scout-674cfb4855-776xt	0
scout	scout-674cfb4855-xcwdj	0
```

The two targets exist now, but they are `down`. The last error names the cause: the path `/metric` returns `404`. The output above leaves out the lines for `kps-operator` and `kps-prometheus`.

## Fix the path

Change `path: /metric` to `path: /metrics` and apply the file a last time:

```sh
kubectl apply -f servicemonitor-scout.yaml
```

Wait about a minute, then check again:

```sh
show_targets
curl -s http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=up{namespace="starfleet"}' |
  jq -r '.data.result[] | "\(.metric.job)\t\(.metric.pod)\t\(.value[1])"'
```

```text
scout	http://10.244.0.10:9898/metrics	up	
scout	http://10.244.0.9:9898/metrics	up	
scout	scout-674cfb4855-776xt	1
scout	scout-674cfb4855-xcwdj	1
```

Both targets are `up` and both `up` series are `1`.

Press Ctrl-C to stop the watch, then grade your work once:

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## What the grader rejects

- Changing the Prometheus resource to select every ServiceMonitor: the first check needs the selector `release: kps` unchanged.
- Renaming the port of the Service `scout` to `metrics`: the targets then work, but the first check needs the port name `http`.
- Fixing only some of the mistakes: the second check needs one healthy target for each ready `scout` endpoint.

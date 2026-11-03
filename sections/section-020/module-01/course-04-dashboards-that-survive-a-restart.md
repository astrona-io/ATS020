# Dashboards That Survive A Restart

A dashboard saved in Grafana lives in its database. In this playground, the database uses temporary pod storage, so replacing the pod deletes dashboards saved only there. A Kubernetes ConfigMap stores configuration outside the pod. Exporting a dashboard into a labelled ConfigMap lets Grafana load it again when a new pod starts.

## Save and export a dashboard

Grafana's application programming interface (API) lets you save the same dashboard that you could build in the browser. A dashboard is a page of panels, and each panel runs queries against a data source. The example below creates a request-rate panel with a fixed unique identifier (UID), `scout-copy`. JavaScript Object Notation (JSON) is the document format Grafana uses for dashboards.

Keep the Grafana port-forward on local port `3300` running. Write files in your own working folder. Save the request body first, so you can read it before sending it.

<!-- astrona:playground:renew -->

Save this as `dashboard-temporary.json`:

```json
{
  "dashboard": {
    "uid": "scout-copy",
    "title": "Scout Requests",
    "schemaVersion": 41,
    "time": {"from": "now-15m", "to": "now"},
    "panels": [
      {
        "id": 1,
        "type": "timeseries",
        "title": "Request rate",
        "gridPos": {"x": 0, "y": 0, "w": 24, "h": 8},
        "datasource": {"type": "prometheus", "uid": "prometheus"},
        "fieldConfig": {"defaults": {"unit": "reqps"}, "overrides": []},
        "targets": [{"refId": "A", "expr": "sum(rate(http_requests_total{namespace=\"starfleet\"}[1m]))"}]
      }
    ]
  },
  "overwrite": true
}
```

Send the document to Grafana. Then create a second copy with UID `temporary-control`, which you will leave only in the database. Check the pod's storage at the same time:

```sh
curl -s -u admin:starfleet -H 'Content-Type: application/json' \
  http://127.0.0.1:3300/api/dashboards/db -d @dashboard-temporary.json | jq '{status, uid}'
jq '.dashboard.uid = "temporary-control" | .dashboard.title = "Temporary Control"' dashboard-temporary.json |
  curl -s -u admin:starfleet -H 'Content-Type: application/json' \
    http://127.0.0.1:3300/api/dashboards/db -d @- | jq '{status, uid}'
kubectl -n monitoring get deploy kps-grafana -o json |
  jq '.spec.template.spec.volumes[] | select(.name=="storage")'
```

The output from the playground was:

```text
{
  "status": "success",
  "uid": "scout-copy"
}
{
  "status": "success",
  "uid": "temporary-control"
}
{
  "emptyDir": {},
  "name": "storage"
}
```

`emptyDir` is a Kubernetes volume that lasts for the life of one pod. A container restart within that pod keeps it; replacing the pod removes it. Grafana backed by persistent storage can keep browser-created dashboards across pod replacements. The loss shown here belongs to this playground's storage settings, rather than every Grafana installation.

Export the dashboard model from Grafana's response. The response also contains metadata, but a provisioning file needs only `.dashboard`. Remove the database `id` and reset `version` while keeping the stable `uid`:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/scout-copy |
  jq '.dashboard | del(.id) | .version = 0' > scout-copy.json
jq '{uid, title, panels: [.panels[].title]}' scout-copy.json
```

The exported file contains:

```text
{
  "uid": "scout-copy",
  "title": "Scout Requests",
  "panels": [
    "Request rate"
  ]
}
```

The export keeps the panel and its query. It also keeps the data source UID `prometheus`, so the destination Grafana instance must have a data source with that UID.

## Load the export from a ConfigMap

Generate a manifest from the exported JSON file. `--dry-run=client` prints the ConfigMap without creating it. The second command adds the label the dashboard sidecar watches, still without applying anything. A sidecar is a helper container in the same pod as Grafana.

```sh
kubectl -n monitoring create configmap dashboard-scout-copy --from-file=scout-copy.json \
  --dry-run=client -o yaml > configmap-dashboard-scout-copy.yaml
kubectl label --local -f configmap-dashboard-scout-copy.yaml grafana_dashboard=1 \
  -o yaml > configmap-dashboard-scout-copy-labelled.yaml
```

You now have the dashboard saved as `configmap-dashboard-scout-copy-labelled.yaml`. Apply it:

```sh
kubectl apply -f configmap-dashboard-scout-copy-labelled.yaml
```

Then check the result. Wait a few seconds for the sidecar to write the file and reload Grafana, then read the provisioning metadata:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/scout-copy |
  jq '{uid: .dashboard.uid, provisioned: .meta.provisioned}'
```

Grafana reports:

```text
{
  "uid": "scout-copy",
  "provisioned": true
}
```

The dashboard now comes from a file. The provider in this playground does not allow saving changes to a provisioned dashboard in Grafana. Change the JSON in the ConfigMap when you want a lasting update.

## Replace the pod and prove recovery

A Deployment manages pod replicas and replaces them when its pod template changes. Restart the Grafana Deployment to create a new pod with empty storage:

```sh
kubectl -n monitoring rollout restart deploy/kps-grafana
kubectl -n monitoring rollout status deploy/kps-grafana --timeout=180s
```

The output, shortened to the restart and completion lines, was:

```text
deployment.apps/kps-grafana restarted
deployment "kps-grafana" successfully rolled out
```

The old port-forward loses its connection when its pod disappears. Stop it with `Ctrl+C`, then start it again in a second terminal and leave it running:

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3300:80
```

Then check both copies and the data source:

```sh
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/scout-copy |
  jq '{uid: .dashboard.uid, provisioned: .meta.provisioned, panels: [.dashboard.panels[].title]}'
curl -s -u admin:starfleet http://127.0.0.1:3300/api/dashboards/uid/temporary-control | jq '{message}'
curl -s -u admin:starfleet http://127.0.0.1:3300/api/datasources/uid/prometheus/health | jq '{status}'
```

The new Grafana pod returns:

```text
{
  "uid": "scout-copy",
  "provisioned": true,
  "panels": [
    "Request rate"
  ]
}
{
  "message": "Dashboard not found"
}
{
  "status": "OK"
}
```

The provisioned dashboard returned with its panel, and Grafana can still query Prometheus. The copy left only in the database is gone. If a provisioned dashboard is missing, first check the ConfigMap's `grafana_dashboard: "1"` label, then read `grafana-sc-dashboard` logs. The sidecar copies the file; Grafana parses and loads the JSON, so invalid JSON can leave a file present without a usable dashboard.

You can now export a dashboard model, store it in a labelled ConfigMap, and prove that a new Grafana pod restores it. Storage decides whether database-only dashboards survive; provisioning gives you a file you can review, version and restore.

## Common pitfalls

> [!WARNING]
> - **Exporting the whole API response.** Provisioning needs the dashboard model, without the outer `dashboard` and `meta` fields.
> - **Changing the data source UID during export.** Panels still refer to that UID; provision the matching data source.
> - **Testing only a container restart.** An `emptyDir` survives that restart. Replace the pod to test recovery from lost temporary storage.
> - **Keeping the old port-forward.** It points at the deleted pod. Start it again before checking the new instance.
> - **Editing only Grafana's database.** Provisioning loads the file again; put lasting changes in the ConfigMap.

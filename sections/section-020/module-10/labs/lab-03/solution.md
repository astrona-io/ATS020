# Solution: Repair Dashboard Data Source References

## Inspect the starting state

The data source UID is `prometheus`; the dashboard refers to `prometheus-main`.

```sh
kubectl -n monitoring get configmap dashboard-scout-overview -o yaml
kubectl -n monitoring get configmap datasource-prometheus -o yaml
```

## Make the repair

Edit the dashboard ConfigMap and replace `prometheus-main` with `prometheus` in each panel and the namespace variable:

```sh
kubectl -n monitoring edit configmap dashboard-scout-overview
```

## Verify the result

Start a port-forward and open Grafana at `http://127.0.0.1:3000`, using `admin` / `starfleet`. Select `starfleet` in the dashboard variable. Each panel must show data. In a second terminal, verify provisioning:

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

```sh
curl -s -u admin:starfleet http://127.0.0.1:3000/api/dashboards/uid/scout-overview | jq '.meta.provisioned, [.dashboard.panels[].title]'
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-020/module-10/labs/lab-03
```

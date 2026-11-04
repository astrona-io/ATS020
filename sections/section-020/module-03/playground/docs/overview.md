# Explore Logs With Loki And LogQL

Loki stores log lines and indexes only their labels. This playground has Kubernetes 1.35.8, Grafana 13.2.3 and Loki 3.7.9. An OpenTelemetry Collector sends the logs of `outpost` and `starfleet` to Loki with the labels `namespace`, `pod` and `container`. There is no grading.

| Namespace | Contents |
| --- | --- |
| `monitoring` | Grafana, Service `kps-grafana` on port `80`, user `admin`, password `starfleet` |
| `logging` | Loki, Service `loki` on port `3100`, and the `collector` DaemonSet |
| `outpost` | Deployments `probe`, `beacon` and `scout`, and StatefulSet `depot` |
| `starfleet` | Deployments `relay` and `shuttle`. `shuttle` sends requests to `probe` |

Grafana has no data source yet. It has a saved dashboard, `Outpost Logs`, whose panels use a data source with the unique identifier (UID) `loki`.

Use a second terminal for each port-forward and leave them running:

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3300:80
```

```sh
kubectl -n logging port-forward svc/loki 3100:3100
```

Open `http://127.0.0.1:3300` to use Grafana. Check which labels Loki holds:

```sh
curl -fsS http://127.0.0.1:3100/loki/api/v1/labels | jq
```

Practice tasks:

- Add the Loki data source with the UID `loki` and the address `http://loki.logging:3100`, then change **Maximum lines**.
- In **Explore**, write a stream selector for `outpost`, then add `|= "ERROR"`.
- Count the streams with errors with `count(rate({namespace="outpost"} |= "ERROR" [5m]))`.
- Edit a panel of `Outpost Logs`, save it, and read the saved query through the API.

This environment is disposable. Grafana's database and Loki's data are both lost when their Pods are replaced.

# Overview: Measure Delivery With DORA Metrics (Playground)

This playground gives you a cluster that has already delivered one workload ten times. Argo CD, a continuous delivery controller, syncs the `scout` Deployment from a Git repository into the cluster. Prometheus scrapes the metrics of Argo CD. You use the history and the metrics to measure the four DORA metrics: deployment frequency, lead time for changes, change failure rate and time to restore service. There is no grading.

## What's in the box

The cluster runs Kubernetes 1.35.8. Setup takes several minutes, because the bootstrap makes ten real commits and waits for Argo CD to sync each one. Two of the ten commits are bad on purpose: they use an image tag that does not exist.

| Namespace | Contents |
| --- | --- |
| `monitoring` | A trimmed kube-prometheus-stack 92.3.0: the Prometheus Operator and one Prometheus. No Alertmanager, no Grafana, no node exporter, no kube-state-metrics. The Service `kps-prometheus` serves port `9090`. Prometheus scrapes every 15 seconds and keeps 6 hours of data |
| `argocd` | Argo CD 3.6.1 with the application controller, the repository server and Redis. The API server, Dex, notifications and ApplicationSet controller are scaled to zero. The Application `scout` syncs automatically. A ServiceMonitor with the label `release: kps` makes Prometheus scrape the Service `argocd-metrics` on port `8082` |
| `gitea` | Gitea 28.1.0, a small Git server, only so that the history has a real Git repository. The repository `starfleet/starfleet-deploy` holds the path `scout` with a Deployment and a Service |
| `starfleet` | `scout`, created by Argo CD from the repository (three replicas of `podinfo` 6.17.0), and `shuttle`, a client pod with `curl` |

The seed gives every commit a committer date between 3 and 45 minutes before the push. Real teams commit first and deploy later. The backdated dates let the playground show a lead time that is more than a few seconds. Your values differ from the values in the course text, because every start makes new commit hashes and times.

## Helpers

Use a second terminal for the port-forwards and leave it running. Port `3000` is for Gitea and port `9090` is for Prometheus. If one of those ports is in use on your machine, choose another local port, for example `23000:3000`, and use it in the commands.

```sh
kubectl -n gitea port-forward svc/gitea 3000:3000
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

The Gitea user is `starfleet` and the password is `starfleet-pass-1`. The repository is public, so the commit list needs no login. This helper runs a PromQL query against Prometheus and prints one line per result series. It removes the labels that every Argo CD series shares, to keep the lines short:

```sh
promql() {
  curl -fsS --data-urlencode "query=$1" http://127.0.0.1:9090/api/v1/query |
    jq -c '.data.result[] | {metric: (.metric | del(.container, .endpoint, .instance, .job, .pod, .service, .exported_namespace, .namespace, .dest_server, .dry_run, .project)), value: .value[1]}'
}
```

## Practice tasks

- Read the delivery history of the Application `scout` from `.status.history` and count the deployments.
- Query `argocd_app_sync_total` and `argocd_app_info` in Prometheus and explain every label.
- Compute the deployment frequency over 6 hours with `increase()` and `round()`.
- Find the two bad deployments in the metrics from the Degraded health of the Application.
- Compute the change failure rate and write it as a recording rule in a PrometheusRule with the label `release: kps`.
- Join the commit times from Gitea with the `deployedAt` times from Argo CD and compute the lead time of each change.
- Compute the time to restore service for each failure.
- Push a new bad commit to the repository and watch Argo CD, the metrics and the Deployment react.

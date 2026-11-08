# Measure Delivery With DORA Metrics — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-040-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8, with a trimmed
kube-prometheus-stack 92.3.0, Gitea 28.1.0 (plumbing) and Argo CD 3.5.4. The
bootstrap creates the Git repository `starfleet-deploy` and the Argo CD
Application `scout`, then makes ten commits (two of them bad on purpose) and
waits for Argo CD to sync each one. Prometheus scrapes Argo CD during the seed,
so the metrics hold the whole delivery history. This is the heaviest
playground in the course: run nothing beside it.

## Run it

```sh
astrona run -c . --trust
astrona destroy ats-020-playground-040-01
```

The destroy command takes the environment name, rather than the directory.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Cluster definition and images |
| `bootstrap/prepare.sh` | Installs Prometheus, Gitea and Argo CD, then runs the seed |
| `bootstrap/seed-history.sh` | Makes ten backdated commits and waits for Argo CD to sync each one |
| `bootstrap/appproject.yaml`, `application.yaml` | The Argo CD project `default` and the Application `scout` |
| `bootstrap/argocd-monitor.yaml` | The ServiceMonitor for the Argo CD application controller |
| `bootstrap/gitea.yaml`, `kps-values.yaml` | Gitea and the trimmed Prometheus stack |
| `manifests/lab-start.yaml` | The `shuttle` client |
| `docs/overview.md` | Learner guide and practice tasks |

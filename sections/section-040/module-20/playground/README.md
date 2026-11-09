# Measure Service Levels And Resource Efficiency — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-040-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8 with metrics-server 0.9.0
(the `metricsServer` addon) and a trimmed kube-prometheus-stack 92.22.0
(Prometheus Operator, one Prometheus, kube-state-metrics, the kubelet scrape
job for cAdvisor; no Alertmanager, no Grafana). The workloads `scout`,
`probe` and `shuttle` run in `starfleet`. The traffic loop in `shuttle` sends
5% of its requests to `scout` to `/status/500`, so the SLI is below a 99%
target. `scout` requests far more than it uses and `probe` requests less than
it uses.

## Run it

```sh
astrona run -c . --trust
astrona destroy ats-020-playground-040-02
```

The destroy command takes the environment name, rather than the directory.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Cluster definition, the metrics-server addon and images |
| `bootstrap/prepare.sh` | Installs Helm if missing and the trimmed Prometheus stack |
| `bootstrap/kps-values.yaml` | Chart values: kube-state-metrics and kubelet scraping on, the rest off |
| `manifests/lab-start.yaml` | `scout`, `probe`, `shuttle`, the traffic loop and the ServiceMonitor |
| `docs/overview.md` | Learner guide and practice tasks |

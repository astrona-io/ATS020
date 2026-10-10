# Scrape Workloads With ServiceMonitor And PodMonitor — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with a trimmed
kube-prometheus-stack 92.3.0 (Prometheus Operator v0.94.1 and one Prometheus
v3.15.0; Alertmanager, Grafana, node-exporter, kube-state-metrics and default
rules off) in `monitoring`, installed by `bootstrap/prepare.sh` with Helm 4.3.0.
Workloads: `scout` (podinfo 6.15.0, Service with port `http`) and `shuttle` in
`starfleet`, and a `scout` pod without a Service in `outpost`. No monitor for
the Starfleet workloads exists. Monitors must carry `release: kps`.

## Run it

```sh
astrona run -c .
astrona destroy ats-020-playground-010-01
```

`astrona destroy` takes the environment name (`metadata.name`), not the config
path. `astrona submit` and `astrona test` do not apply — there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, bootstrap) |
| `bootstrap/prepare.sh` | Installs Helm if missing and the trimmed Prometheus stack |
| `bootstrap/kps-values.yaml` | Helm values that trim kube-prometheus-stack |
| `manifests/lab-start.yaml` | Namespaces and the Starfleet workloads |
| `docs/overview.md` | What the environment contains and ideas to try |

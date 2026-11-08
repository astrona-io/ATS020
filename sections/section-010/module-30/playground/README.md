# Alert With PrometheusRule And Alertmanager — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-010-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with a trimmed
kube-prometheus-stack 92.3.0 (Prometheus Operator v0.94.1, one Prometheus
v3.15.0, one Alertmanager v0.34.1 with the chart's default configuration) in
`monitoring`, installed by `bootstrap/prepare.sh` with Helm 4.3.0. `scout`
(podinfo 6.15.0) in `starfleet` with a ServiceMonitor, `shuttle` sending one
healthy request per second, and `alert-receiver` (python:3.13-alpine with a
script from a ConfigMap) in `monitoring`, which prints every webhook
notification. PrometheusRules need `release: kps`; AlertmanagerConfigs are
selected from every namespace.

## Run it

```sh
astrona run -c .
astrona destroy ats-020-playground-010-03
```

`astrona destroy` takes the environment name (`metadata.name`), not the config
path. `astrona submit` and `astrona test` do not apply — there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, bootstrap) |
| `bootstrap/prepare.sh` | Installs Helm if missing and the trimmed Prometheus stack with Alertmanager |
| `bootstrap/kps-values.yaml` | Helm values that trim kube-prometheus-stack |
| `manifests/lab-start.yaml` | scout, its ServiceMonitor, the shuttle loop and the alert-receiver webhook |
| `docs/overview.md` | What the environment contains and ideas to try |

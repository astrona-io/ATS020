# Build Grafana Dashboards As Code — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8, with Prometheus,
the Prometheus Operator and Grafana 13.2.3 in `monitoring`. Two namespaces
hold `scout` workloads with ServiceMonitors. A client sends steady requests,
including errors and delayed responses. No application dashboard or data
source exists at startup.

## Run it

```sh
astrona run -c . --trust
astrona destroy ats-020-playground-020-01
```

The destroy command takes the environment name, rather than the directory.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Cluster definition and images |
| `bootstrap/prepare.sh` | Install the trimmed monitoring stack |
| `bootstrap/kps-values.yaml` | Stack settings |
| `manifests/lab-start.yaml` | Workloads, traffic and monitors |
| `docs/overview.md` | Learner guide and practice tasks |

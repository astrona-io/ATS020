# Query Metrics With PromQL — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-010-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single-node kind cluster (`kindest/node:v1.35.8`) with a trimmed
kube-prometheus-stack 92.3.0 (Prometheus Operator v0.94.1 and one Prometheus
v3.15.0, 15-second scrape interval) in `monitoring`, installed by
`bootstrap/prepare.sh` with Helm 4.3.0. `scout` (podinfo 6.15.0) runs in
`starfleet` (two replicas) and `outpost` (one replica), each with a Service and
a ServiceMonitor. `shuttle` runs a traffic loop from a ConfigMap: one request
per second to each `scout`, one `/status/500` every 5 seconds and one
`/delay/1` every 10 seconds to the `starfleet` `scout`.

## Run it

```sh
astrona run -c .
astrona destroy ats-020-playground-010-02
```

`astrona destroy` takes the environment name (`metadata.name`), not the config
path. `astrona submit` and `astrona test` do not apply — there is no grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime, preloaded images, bootstrap) |
| `bootstrap/prepare.sh` | Installs Helm if missing and the trimmed Prometheus stack |
| `bootstrap/kps-values.yaml` | Helm values that trim kube-prometheus-stack |
| `manifests/lab-start.yaml` | Workloads, Services, ServiceMonitors and the traffic loop |
| `docs/overview.md` | What the environment contains and ideas to try |

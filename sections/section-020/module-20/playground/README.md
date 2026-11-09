# Collect Pod Logs With The OpenTelemetry Collector — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-020-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8, with cert-manager 1.21.3,
the OpenTelemetry Operator 0.160.0 and a trimmed Prometheus stack (the
Prometheus Operator and one Prometheus) in `monitoring`. `scout` runs in
`starfleet`, `probe` runs in `outpost`, and a `shuttle` pod sends steady
requests, including a `500` response every fourth second. No Collector exists
at startup.

## Run it

```sh
astrona run -c . --trust
astrona destroy ats-020-playground-020-02
```

The destroy command takes the environment name, rather than the directory.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Cluster definition and images |
| `bootstrap/prepare.sh` | Install cert-manager, the operator and the trimmed monitoring stack |
| `bootstrap/kps-values.yaml` | Stack settings |
| `manifests/lab-start.yaml` | Workloads and the traffic loop |
| `docs/overview.md` | Learner guide and practice tasks |

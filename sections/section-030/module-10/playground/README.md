# Run An OpenTelemetry Collector With The Operator — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8, with cert-manager
1.21.2 and Jaeger 2.22.0 (in `observability`). The `scout` workload in
`starfleet` creates spans and tries to send them to a Collector Service that
does not exist yet. The OpenTelemetry Operator is not installed: the reader
installs it.

## Run it

```sh
astrona run -c . --trust
astrona destroy ats-020-playground-030-01
```

The destroy command takes the environment name, rather than the directory.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Cluster definition and images |
| `bootstrap/prepare.sh` | Install cert-manager and wait for its webhook |
| `manifests/lab-start.yaml` | Jaeger, `scout` with tracing on, and the traffic client |
| `docs/overview.md` | Learner guide and practice tasks |

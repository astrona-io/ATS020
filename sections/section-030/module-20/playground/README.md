# Add Tracing Without Code Changes Using Auto-Instrumentation — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-030-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8, with cert-manager
1.21.3, the OpenTelemetry Operator 0.162.0, a working Collector `otel`
(contrib 0.165.0) and Jaeger 2.23.0. The `scout` workload in `starfleet`
creates its own spans. The `relay` workload is a small Node.js service that
calls `scout`. It has no instrumentation and no annotation yet: the reader
adds both and follows one trace across the two services.

## Run it

```sh
astrona run -c . --trust
astrona destroy ats-020-playground-030-02
```

The destroy command takes the environment name, rather than the directory.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Cluster definition and images |
| `bootstrap/prepare.sh` | Install cert-manager and the Operator, and wait for the webhook |
| `manifests/lab-start.yaml` | Jaeger, the Collector, `scout`, `relay` and the traffic client |
| `docs/overview.md` | Learner guide and practice tasks |

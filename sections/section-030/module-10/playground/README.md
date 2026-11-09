# Run An OpenTelemetry Collector With The Operator — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8, with cert-manager
1.21.3, the OpenTelemetry Operator 0.162.0 and Jaeger 2.22.0 (in
`observability`). The `scout` workload in `starfleet` creates spans and tries
to send them to a Collector Service that does not exist yet: the reader
creates the Collector. The `probe` workload is a small Python trace emitter
that sends its spans straight to Jaeger; the reader points its `TARGET_URL`
at a missing Service to practise finding spans that end with an error.

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
| `bootstrap/prepare.sh` | Install cert-manager and the OpenTelemetry Operator, and wait for the Operator webhook |
| `manifests/lab-start.yaml` | Jaeger, `scout` with tracing on, the traffic client and the `probe` trace emitter |
| `docs/overview.md` | Learner guide and practice tasks |

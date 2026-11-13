# Diagnose And Fix Broken Platform Components — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-050-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8 with a trimmed
kube-prometheus-stack 93.3.0 (Prometheus Operator and one Prometheus). The
platform starts broken on purpose: the Service of the `starfleet-policy`
webhook has no endpoints, the serving certificate of the `outpost-policy`
webhook has expired, and the Prometheus Operator is scaled to zero. The
bootstrap never fixes a fault.

## Run it

```sh
astrona run -c . --trust
astrona destroy ats-020-playground-050-02
```

The destroy command takes the environment name, rather than the directory.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Cluster definition and images |
| `bootstrap/prepare.sh` | Installs the trimmed Prometheus stack, then scales the operator to zero |
| `bootstrap/kps-values.yaml` | Helm values for kube-prometheus-stack |
| `manifests/lab-start.yaml` | The workloads, the two webhooks with their CA and certificates, the ServiceMonitor and the PrometheusRule |
| `docs/overview.md` | The only page the learner sees |

The certificates in `lab-start.yaml` were made once with `openssl`. The
`outpost-policy` certificate is valid from 2025-01-01 to 2025-01-08, so it is
expired on every run. The CA is valid for 100 years.

# Triage And Fix Failing Workloads — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-020-playground-050-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — no grading

A single-node kind cluster running Kubernetes 1.35.8 with the metrics-server
add-on. The namespace `starfleet` starts broken on purpose: `scout` and
`bridge` are Pending, `probe` fails its liveness probe, `engine` is in
CrashLoopBackOff, `cargo` is OOMKilled and `beacon` is in ImagePullBackOff.
`shuttle` is healthy. No Prometheus stack runs. The bootstrap never fixes a
fault.

## Run it

```sh
astrona run -c . --trust
astrona destroy ats-020-playground-050-01
```

The destroy command takes the environment name, rather than the directory.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Cluster definition and images |
| `bootstrap/prepare.sh` | Waits until metrics-server answers |
| `manifests/lab-start.yaml` | The namespace, `shuttle` and the six faulty workloads |
| `docs/overview.md` | The only page the learner sees |

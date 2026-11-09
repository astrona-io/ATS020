---
estimated_duration: 25m
---
# Query Logs With Loki And LogQL Playground

Ungraded environment for Kubernetes 1.35.8, Grafana 13.2.3 and Loki 3.7.9 in single-binary mode. Environment preparation installs Grafana from a trimmed kube-prometheus-stack 92.22.0 and saves one starting dashboard. An OpenTelemetry Collector DaemonSet ships logs from `outpost` and `starfleet` to Loki as plumbing. The terminal needs kubectl, curl and jq, plus Helm 4.x, which is installed if missing. All images are listed in the environment configuration for preloading.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-30/playground
astrona destroy ats-020-playground-020-03
```

Built for astrona CLI v0.4.14. Author checks are offline only: configuration validation, shell syntax, YAML parsing and Helm rendering. Built without booting on 2026-11-04. This environment has not been booted or tested against a live cluster.

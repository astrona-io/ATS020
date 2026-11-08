---
title: "Get Your Machine Ready"
maturity: published
reviewed: "2026-11-08"
---

# Get Your Machine Ready

Every playground and lab in this course runs locally on your machine in a small Kubernetes cluster in `kind` or in a `vm`. The `astrona` CLI creates and configures the environment, grades your lab work, and removes the environment when you are finished.

This page walks you through the required tools, introduces the `astrona` commands you will use throughout the course, and explains how to troubleshoot problems when an environment fails to start.

## What you need

All playgrounds and labs use the same tools. Have the following installed before you begin:

| Tool | What you use it for |
| --- | --- |
| **Docker or Podman** | Runs the containers that make up your local Kubernetes cluster. |
| **`kind`** | Creates a Kubernetes cluster inside Docker or Podman. |
| **`kubectl`** | Interacts with the cluster to manage resources and inspect workloads. |
| **`astrona` CLI** | Creates and manages playgrounds and labs, and submits your work for grading. |
| **`jq`** | Extracts specific fields from JSON returned by `kubectl` and the Prometheus API. |
| **Web browser** | Opens Prometheus, Grafana, and Jaeger through connections created with `kubectl port-forward`. |

### Memory and internet access

Allocate **at least 8 GiB of memory** to your container engine.

You also need **outbound internet access during startup**. The environments download Helm charts and container images for Prometheus, Grafana, the OpenTelemetry Operator, and Jaeger. They also install Helm automatically if it is missing.

Without internet access, startup will fail with network errors. Modules that include a GitOps controller may take longer to start.

### Set up your machine

Run the following command to check for missing prerequisites and get help installing them:

```sh
astrona setup
```

`astrona setup` identifies what is missing, explains the proposed steps, and asks for confirmation before making changes. On macOS, it can install `kind`, `kubectl`, and Podman. You must install `jq` separately.

### Check your machine

You can check whether your machine meets the requirements at any time:

```sh
astrona check
```

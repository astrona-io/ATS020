---
maturity: published
last_reviewed: "2026-11-08"
---

# Welcome To The Course

This course prepares you for the **Observability and Operations** domain of the Linux Foundation’s **Certified Cloud Native Platform Engineer (CNPE)** exam.

This page introduces the intended audience, learning outcomes, key terminology, and example application used throughout the course. It also explains how the course is structured.

## Who this course is for

This course is for learners who are familiar with Kubernetes fundamentals, including namespaces, Deployments, Services, pod labels, and commands such as `kubectl logs`, `kubectl describe`, and `kubectl exec`.

You do not need prior experience with the following tools:

- Prometheus
- Grafana
- OpenTelemetry
- Jaeger

Each new concept is explained when it is first introduced.

## What you can do at the end

The exam is hands-on. You work in a remote desktop environment with terminal access to a set of hosts, completing 15–20 tasks within two hours. Each task requires you to configure, troubleshoot, or verify something in a live environment.

The exam covers a broad range of tools and expects you to use them to solve practical problems. This course therefore focuses on applying what you learn: setting up components, checking that they work, and verifying the results through queries, traces, real requests, or dashboards.

The Observability and Operations domain is divided into three topics. Each topic maps to a set of practical skills you will develop throughout the course.

## The words this course uses

This course uses each tool’s official terminology so you can recognise the terms in its interface, documentation, logs, and the exam. Each term is briefly explained the first time it appears on a page. The following terms are used throughout the course.

A **Pod** is the smallest deployable unit in Kubernetes and contains one or more containers that run together. A **namespace** groups and scopes resources within a cluster.

A **request** is a call from a client to a server. The **response** is the answer the server sends back.

**Observability** is the ability to understand a system’s internal behaviour by examining the data it produces. This course focuses on three types of data, commonly called **signals**:

| Signal | What it tells you | Tools used in this course |
| --- | --- | --- |
| Metric | A numeric measurement recorded over time, such as the number of requests per second. | Prometheus, with visualisation in Grafana |
| Log | A record of an event produced by an application or system. | `kubectl logs` for container logs; the OpenTelemetry Collector for collecting and forwarding logs |
| Trace | The journey of a request through a system, including the duration of individual operations. | The OpenTelemetry Collector for collecting and forwarding traces; Jaeger for storing and exploring them |

## The example app in your playground

Every playground and lab uses the same small application, with components named after a fleet of spaceships. It runs in the `starfleet` and `outpost` namespaces and includes:

- **`scout`**: a Deployment running an HTTP API on port `9898` that exposes Prometheus metrics.
- **`probe`**: a Deployment running an HTTP echo server on port `8080` that can deliberately return slow responses or errors.
- **`shuttle`**: a client Pod with `curl`, used to send test requests to the application.

Many playgrounds and labs, along with the entire incident section, begin with deliberately introduced faults. These faults are part of the exercises and give you opportunities to practise investigating and resolving problems.

## How to read a page

Each module begins with a **landing page** that introduces its learning objectives, prerequisites, and chapter order. Start the module’s playground at the bottom of that page and keep it running as you work through the chapters.

The chapters read like a technical book. Each chapter introduces a problem, explains the concepts needed to solve it, and closes with a recap of what you have learned. Practical steps appear alongside the explanations: what to run, why it matters, the command, its expected output, and how to interpret the result. Run each step in your playground as you reach it to connect the explanation with real behaviour.

Every chapter ends with a **Common pitfalls** box describing frequent mistakes and how to recognise them. Some pages also include a **Tip** box with a useful habit or shortcut you can apply elsewhere. These boxes look like this:

> [!TIP]
> **A useful habit or shortcut.** Practical advice you can apply throughout the course and in your own work.

> [!WARNING]
> **Common pitfalls.** Frequent mistakes related to the chapter’s concepts, with guidance on how to recognise them.

When a chapter has an associated graded lab, it ends with a **Your mission** section. This introduces the task and provides the commands for managing the lab environment, in order:

1. Pause the playground with `astrona stop`.
2. Start the lab with `astrona run`.
3. Complete the task and submit your work for grading with `astrona submit`.
4. Remove the lab with `astrona destroy`.
5. Restart the playground with `astrona start` and continue reading.

Attempt the lab independently before consulting its solution.

Each module ends with a **Summary** page that reviews the main ideas in a few short paragraphs. This page also includes the step to remove the playground, leaving your machine ready for the next module.

Throughout the course, code blocks distinguish commands to run from output to inspect. Copy commands as written unless the instructions explicitly ask you to replace a value. If your output differs from the example, investigate the difference—it may reveal something useful about your environment or the problem you are solving.

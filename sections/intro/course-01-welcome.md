# Welcome To The Course

This course trains you for the **Observability and Operations** part of the **Certified Cloud Native Platform Engineer (CNPE)** exam. That part is 20% of the exam. This page tells you who the course is for, what you can do at the end, which words and example app it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, Services, pod labels, `kubectl logs`, `kubectl describe` and `kubectl exec`. You do not need to know Prometheus, Grafana, OpenTelemetry or Jaeger yet. Each new idea is explained the first time it appears.

## What you can do at the end

The exam is hands-on. You get a set of hosts, a terminal and 15 to 20 tasks in two hours, and you must make things work on a live cluster. The exam touches many tools but expects only working depth in each one. So this course does not ask you to remember words. It asks you to set something up, check that it works, and prove it with a query, a trace or a real request. The exam groups this part into three topics, and each one turns into a set of skills you will practise.

The first topic is **implementing monitoring, alerting, logging and tracing**. You will learn to:

- Get a workload's metrics into Prometheus with a `ServiceMonitor` or `PodMonitor`, and find out why a target does not appear.
- Write PromQL queries for request rate, error rate and latency.
- Write alerting rules in a `PrometheusRule`, and route the alerts to a receiver with Alertmanager.
- Build a Grafana dashboard, and collect pod logs with the OpenTelemetry Collector and turn error lines into a metric.
- Send traces through an OpenTelemetry Collector to Jaeger, and add tracing to an app without changing its code.

A platform also has to show whether it is getting better, so the second topic is **measuring and improving platform efficiency**. You will learn to:

- Measure the four DORA delivery metrics from the history of a GitOps controller.
- Define a service level objective and calculate how much error budget is left.
- Compare what workloads request with what they really use, and find the waste.

Things break, so the third topic is **diagnosing and remediating incidents**. You will learn to:

- Find why a pod is `Pending`, in `CrashLoopBackOff`, `OOMKilled` or in `ImagePullBackOff`, and fix it.
- Find and fix a broken platform component: a failing admission webhook, a stopped controller, a GitOps sync that is stuck, or an expired certificate.

Everything is built and checked on **Kubernetes 1.35**, the version the exam uses.

## The words this course uses

The pages use each tool's own terms, because those are the words you meet in the product, the logs and the exam. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

A **pod** runs one copy of an application, and a **namespace** groups pods and other objects inside the cluster. A **request** is one call that a client sends to a server, and the **response** is the answer it gets back. Observability means you can tell what a system is doing from the data it sends out. That data comes in three kinds, often called signals:

| Signal | What it is | Tool in this course |
| --- | --- | --- |
| Metric | A number measured over time, for example requests per second | Prometheus, shown in Grafana |
| Log | A line of text a program writes when something happens | `kubectl logs`, and the OpenTelemetry Collector for the whole cluster |
| Trace | The path of one request through several services, with the time each step took | Jaeger, collected by the OpenTelemetry Collector |

**OpenTelemetry** is a vendor-neutral standard for producing and sending all three signals. Its **Collector** receives the data, changes it if needed, and sends it on to the right backend.

## The example app in your playground

Every playground and lab runs the same small app, named after a fleet of spaceships. It lives in the namespaces `starfleet` and `outpost`. The `scout` Deployment is an HTTP API on port `9898` that publishes its own Prometheus metrics. The `probe` Deployment is an HTTP echo server on port `8080`: you can ask it for a slow response or an error on purpose. You send your test requests from the `shuttle` pod, a client with `curl`.

Many playgrounds and labs, and all of the incident section, start with something broken on purpose. That is the material, not a fault in the course.

## How the course is laid out

The course has five sections. They follow the order you build observability on a platform: collect metrics first, then show them and the logs, then follow single requests, then measure the platform as a whole, and last use all of it to fix incidents.

| Section | What it covers |
| --- | --- |
| 010 | Metrics And Alerting With Prometheus |
| 020 | Dashboards And Logs |
| 030 | Distributed Tracing With OpenTelemetry And Jaeger |
| 040 | Measuring Platform Efficiency |
| 050 | Diagnosing And Remediating Incidents |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster with a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several tasks or faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, the real output, and then what that output shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type or what you will see. Never change a command to make it "look right". If the result is different from the page, that difference is the lesson.

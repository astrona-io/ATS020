---
maturity: published
last_reviewed: "2026-11-08"
---

# How This Course Is Made

This page explains how the course content is written and reviewed, introduces the people behind it, and shows how you can contribute improvements.

## How the content is written

The course uses fixed versions of Kubernetes, Prometheus, Grafana, the OpenTelemetry Collector, and Jaeger. All environments and examples are built and checked against those versions. Descriptions of a tool’s behaviour refer to the version used in the course.

Technical explanations are checked against official documentation, including the Prometheus and Prometheus Operator documentation, the OpenTelemetry Collector and Operator documentation, the Jaeger and Grafana documentation, and the Kubernetes debugging guides. Each page provides the explanations you need to follow along without having to consult external resources.

Command output comes from actual runs. When output is shortened, it is clearly marked. If verified output is unavailable, the page describes the expected result in words.

Graded labs follow the same approach. Their graders check behaviour by querying Prometheus, reading traces from Jaeger, or sending real requests and inspecting the responses. Many graders also check for changes that hide a problem without resolving it, such as deleting a firing alert or removing a memory limit instead of adjusting it appropriately. Each lab includes a reference solution that is tested against its grader to verify that a correct solution passes.

AI tools help create substantial parts of the course. A maintainer reviews every change before publication, and the same technical checks apply to all content, regardless of how it was written.

## Maintainers

The core maintainers develop the course, review contributions, and keep the content accurate and up to date.

| Maintainer | GitHub |
| --- | --- |
| Paris Nakita Kejser | [@parisnakitakejser](https://github.com/parisnakitakejser) |

### Contributors

Thank you to everyone who has helped improve the course. See the full list on the [GitHub contributors page](https://github.com/astrona-io/ATS020/graphs/contributors).

### Become a maintainer

Interested in becoming a core maintainer? Get in touch—we welcome people who want to help shape and maintain the course.

## Found a mistake? Report it

Mistakes can slip through despite our checks. If a command fails, an explanation is inaccurate, or a lab rejects a correct solution, please report it. Your feedback helps improve the course for everyone.

To report a problem:

1. [Open a GitHub issue](https://github.com/astrona-io/ATS020/issues/new).
2. Identify the affected page or lab. Include its file path if possible, such as `sections/section-010/module-10/labs/lab-01`.
3. Include the command you ran and the output or error you received.
4. Explain what you expected to happen.

Before sharing output, logs, screenshots, or configuration, remove passwords, tokens, private keys, and other sensitive information. Check Grafana and Alertmanager configuration carefully, as these files may contain credentials.

Want to contribute a fix? Pull requests are welcome in the [course repository](https://github.com/astrona-io/ATS020).

## License

The course is published under the [Apache License 2.0](https://github.com/astrona-io/ATS020/blob/main/LICENSE). You are welcome to use it, share it and build on it under the terms of that license.

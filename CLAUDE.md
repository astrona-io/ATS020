# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.

## About this repo (ATS020 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** pass the **Observability and Operations** domain of the
  **Certified Cloud Native Platform Engineer (CNPE)** exam. It is 20% of the
  exam.
- **What the exam really tests:** making a platform visible and keeping it
  running, by hand, on a live cluster, under time pressure. The exam is 15 to
  20 hands-on tasks in 2 hours, run over `ssh <node>` with `kubectl`, `yq` and
  `curl`. It tests breadth more than depth: the student must get a scrape
  target `UP`, write a PromQL query that returns the right number, route an
  alert, get a trace into Jaeger, and find and fix a broken workload or
  platform component. Every explanation should lead to a command they can
  run, and every fix should be proved with a query, a trace or a working
  request.
- **The three exam competencies (curriculum items):**
  - Implementing Monitoring, Alerting, Logging, and Tracing Solutions
  - Measuring and Improving Platform Efficiency Using Deployment Metrics and
    Performance Indicators
  - Diagnosing and Remediating Platform Issue and Incident Scenarios
- **Documentation in the exam:** only <https://kubernetes.io/docs>, the
  Kubernetes blog, and a per-task "Quick Reference" for the tool in that task.
  So pages teach where a field lives and how to read a tool's own status, not
  long lists to memorise.
- **Teach only the official CNPE tools.** The exam names Argo, Crossplane,
  Flagger, Flux, Gatekeeper, Grafana, Istio, Jaeger, Kyverno, Linkerd, OPA,
  OpenCost, OpenTelemetry, Prometheus and Tekton, plus built-in Kubernetes
  (events, `kubectl logs`, `kubectl debug`, probes). In this domain that
  means Prometheus (with the Prometheus Operator and Alertmanager), Grafana,
  OpenTelemetry, Jaeger, Argo CD and Flux, and Kubernetes itself. Any other
  tool (Helm, cert-manager, metrics-server, Gitea) is plumbing: a playground
  may install it, but no page teaches it. There is no Loki and no LogQL in
  this course; logs are collected and processed with the OpenTelemetry
  Collector and counted into Prometheus metrics.
- **The sections:** the order is collect first, then show, then trace, then
  measure the platform, then fix it. Each section stands on its own.

  | Section | Title | Curriculum item |
  | --- | --- | --- |
  | 010 | Metrics And Alerting With Prometheus | Implementing Monitoring, Alerting, Logging, and Tracing Solutions |
  | 020 | Dashboards And Logs | Implementing Monitoring, Alerting, Logging, and Tracing Solutions |
  | 030 | Distributed Tracing With OpenTelemetry And Jaeger | Implementing Monitoring, Alerting, Logging, and Tracing Solutions |
  | 040 | Measuring Platform Efficiency | Measuring and Improving Platform Efficiency Using Deployment Metrics and Performance Indicators |
  | 050 | Diagnosing And Remediating Incidents | Diagnosing and Remediating Platform Issue and Incident Scenarios |

- **The version:** everything is built and checked on **Kubernetes 1.35**
  (the exam version) on a single-node `kind` cluster, `kind` v0.33.0 with the
  node image `kindest/node:v1.35.8`. Pinned tools:

  | Tool | Version |
  | --- | --- |
  | kube-prometheus-stack (Helm chart) | 92.3.0 |
  | metrics-server | 0.9.0 |
  | Grafana | 13.2.3 |
  | OpenTelemetry Operator | 0.160.0 |
  | OpenTelemetry Collector (contrib) | 0.162.0 |
  | Jaeger | 2.22.0 |
  | cert-manager (needed by the OpenTelemetry Operator) | 1.21.2 |
  | Argo CD (section 040 only) | 3.5.4 |
  | Flux (section 040 only) | 2.9.6 |
  | Gitea (section 040 only, plumbing) | 28.1.0 |
  | Helm | 4.3.0 |

  Do not teach fields, flags or output from other versions without saying so.
- **The main sources:** the Prometheus and Prometheus Operator documentation,
  the OpenTelemetry Collector and Operator documentation, the Jaeger and
  Grafana documentation, and the Kubernetes debugging pages. Check every page against
  them (list at the end of this file).

### Terms, not metaphors

Explanations use the tools' own words. Define each one in plain technical
language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| Metric | A number a program reports about itself, for example the count of HTTP requests it has served |
| Time series | One metric name plus one set of label values, with a value stored at each scrape |
| Label | A key-value pair on a time series (`namespace="starfleet"`) used to filter and group |
| Scrape | Prometheus sends an HTTP `GET` to a target's `/metrics` endpoint and stores what it reads |
| Target | One endpoint Prometheus scrapes; `up` is `1` when the last scrape worked and `0` when it failed |
| PromQL | Prometheus Query Language, used to select, filter and calculate over time series |
| Counter / gauge / histogram | A value that only goes up, a value that goes up and down, and a set of buckets that count observations by size |
| `rate()` | Per-second increase of a counter over a time range, for example `rate(http_requests_total[5m])` |
| Prometheus Operator | A controller that runs Prometheus and Alertmanager and turns its custom resources into their configuration |
| ServiceMonitor | A Prometheus Operator resource that tells Prometheus to scrape the endpoints of matching Services |
| PodMonitor | Like a ServiceMonitor, but selects pods directly, with no Service needed |
| PrometheusRule | A Prometheus Operator resource that holds alerting rules and recording rules |
| Recording rule | A PromQL expression Prometheus runs on a schedule and stores as a new time series |
| Alerting rule | A PromQL expression that fires an alert while it returns results for longer than `for:` |
| Alertmanager | The component that receives alerts from Prometheus, groups them, silences them and sends notifications |
| Route / receiver | In Alertmanager, a route matches alerts by label and sends them to a receiver, the place a notification goes (webhook, email) |
| Grafana dashboard | A set of panels, each running a query against a data source and drawing the result |
| Data source | A connection Grafana uses to read data, for example Prometheus or Jaeger |
| Log record | One log line as the OpenTelemetry Collector holds it, with its body, timestamp, severity and attributes such as `k8s.namespace.name` |
| Connector | A Collector part that is the exporter of one pipeline and the receiver of another, for example the count connector that turns log records into a metric |
| OpenTelemetry (OTel) | A vendor-neutral standard and set of tools for metrics, logs and traces |
| OTLP | OpenTelemetry Protocol, the wire format for sending telemetry, on port `4317` (gRPC) and `4318` (HTTP) |
| OpenTelemetry Collector | A program that receives, processes and exports telemetry |
| Receiver / processor / exporter / pipeline | The Collector's parts: where data comes in, what changes it, where it goes, and the chain that connects them per signal |
| OpenTelemetryCollector | The OpenTelemetry Operator's resource that deploys and configures a Collector |
| Instrumentation | The OpenTelemetry Operator's resource that tells it how to inject auto-instrumentation into pods that ask for it with an annotation |
| Trace / span | A trace is the whole path of one request through several services; a span is one timed step in it |
| Context propagation | Passing the trace ID from one service to the next in a request header (`traceparent`) |
| Jaeger | A tracing backend that stores traces and shows them in a web UI |
| SLI / SLO / error budget | A measured service level (the share of good requests), the target for it (99.5% over 30 days), and how much failure the target still allows |
| DORA metrics | Four delivery measures: deployment frequency, lead time for changes, change failure rate, and time to restore service |
| Requests vs usage | What a container asked the scheduler for, compared with what it really uses; the gap is waste |
| Event | A short Kubernetes record of something that happened to an object, shown by `kubectl get events` and `kubectl describe` |
| Pending | A pod the scheduler has not placed on a node yet |
| CrashLoopBackOff | A container that keeps exiting; the kubelet waits longer before each restart |
| OOMKilled | The kernel stopped a container because it used more memory than its limit |
| ImagePullBackOff | The kubelet cannot pull the container image and waits longer before each try |
| Admission webhook | An HTTP service the API server calls before it stores an object; a failing one can block every create |

### The example workloads

Every section uses the same small app, the Starfleet, in the namespaces
`starfleet` and `outpost`. The Kubernetes names are space names, so describe
them in technical terms and use them as they are.

| Kubernetes name | Image | What it is |
| --- | --- | --- |
| `scout` (Deployment and Service) | `ghcr.io/stefanprodan/podinfo:6.15.0` | HTTP API on port `9898`; serves Prometheus metrics on `/metrics` (`http_requests_total{status}` counter and `http_request_duration_seconds{method,path,status}` histogram). `/status/<code>` returns that code and `/delay/<seconds>` waits, so error ratio and latency come from `scout`. Tracing: `--otel-service-name` switches on OpenTelemetry tracing and log export (verified on 6.15.0; endpoint through the standard `OTEL_EXPORTER_OTLP_*` variables, verify at build) |
| `probe` (Deployment and Service) | `mccutchen/go-httpbin:2.25.0` (Docker Hub tag has no `v`; `v2.25.0` does not exist) | HTTP echo server on port `8080` with `/delay/N` and `/status/<code>`. It serves **no** Prometheus metrics (`/metrics` is `404`), so metric modules never scrape it. It logs one line per request, with `level=ERROR` for a `5xx`, which makes it the log source for the logging module |
| `shuttle` | `curlimages/curl` | Client pod; test requests are sent from here with `kubectl exec deploy/shuttle -- curl ...` |
| `relay` (planned, section 030) | `node:22-alpine` with a small HTTP server script from a ConfigMap | A front service that calls `scout`, used for auto-instrumentation because the OpenTelemetry Operator's Node.js injection works without eBPF; decide and verify at build |

The workloads use the `default` service account. Do not add other example
apps to a page until a playground actually runs them.

### Environment facts the text must respect

- **Pin the cluster in `config.yaml`.** astrona's kind runtime takes
  `runtime.kind.image: kindest/node:v1.35.8` (or `runtime.kind.version`),
  `runtime.kind.nodes.workers`, `featureGates`, `runtimeConfig`,
  `preloadImages` and addons (`metricsServer`, `certManager`,
  `gatewayAPI: envoy`, `cni: calico`); see `astrona schema`. Prefer an addon
  over a hand-written install when it fits. It does not expose
  `kubeadmConfigPatches` or `extraMounts`.

- **Trim kube-prometheus-stack.** The full chart is too heavy for the
  maintainer's machine (Podman with 10 GiB that also runs the platform
  stack). Playgrounds install it with only what the module needs: one
  Prometheus replica, Alertmanager only where alerting is taught, Grafana only
  where dashboards are taught, and `nodeExporter`, `kubeStateMetrics` and the
  default rules and dashboards switched off unless the module uses them. Say
  on the page which parts are installed.
- **Prometheus only reads resources it is told to select.** With the chart's
  defaults, a ServiceMonitor or PodMonitor must carry the label the
  Prometheus resource selects (or the chart must set
  `serviceMonitorSelectorNilUsesHelmValues: false`). Check which one the
  playground uses and say it on the page; this is the most common reason a
  new target never appears.
- **Reach the UIs with port-forward.** There is no load balancer on `kind`.
  Pages use `kubectl port-forward` for Prometheus (`9090`), Alertmanager
  (`9093`), Grafana (`3000`) and Jaeger (`16686`). Check the Service names
  the pinned charts create before writing them down.
- **The OpenTelemetry Operator needs cert-manager** for its webhook
  certificates. Install cert-manager first and wait for it to be ready.
- **Auto-instrumentation happens at pod creation.** An `Instrumentation`
  resource and the `instrumentation.opentelemetry.io/inject-<language>`
  annotation only affect pods created after both exist; existing pods must be
  restarted.
- **Section 040 installs a GitOps controller** (Argo CD, or Flux where
  stated) and an in-cluster Gitea (plumbing only), because DORA metrics are read from
  deployment history. These are the heaviest environments in the course.
- **Section 050 environments start broken on purpose.** A playground or lab
  applies a faulty manifest (a pod that cannot be scheduled, a bad image tag,
  a memory limit that is too low, a webhook pointing at a missing Service, a
  controller scaled to zero, an expired certificate). The fault is the
  material. Never "fix" it in the bootstrap.
- **Telemetry arrives late.** Prometheus scrapes every 30 seconds by default,
  alerts wait for `for:`, and the Collector batches records before it exports
  them. Commands and graders that read metrics, alerts,
  logs or traces right after a change need a short wait or retry.
- **Verified on the pinned versions (section 010 builds, 2026-10-10):**
  - kube-prometheus-stack 92.3.0 with `fullnameOverride: kps` creates the
    Services `kps-prometheus` (`9090`), `kps-alertmanager` (`9093`),
    `kps-grafana` (`80`) and `kps-operator`; images: prometheus-operator and
    config-reloader `v0.94.1`, Prometheus `v3.15.0-distroless`, Alertmanager
    `v0.34.1`, Grafana `13.2.3-distroless`, k8s-sidecar `2.14.1`,
    kube-webhook-certgen `1.8.9`.
  - The Prometheus resource selects ServiceMonitors, PodMonitors and
    PrometheusRules with `release: kps`, from every namespace. The
    Alertmanager resource selects every AlertmanagerConfig (empty selectors).
  - A monitor or rule change reaches the running Prometheus about 60 seconds
    after `kubectl apply` (mounted Secret / ConfigMap propagation).
  - The operator uses `role: endpoints` discovery; dropped targets carry
    `__meta_kubernetes_endpoint_port_name`.
  - An AlertmanagerConfig gets an injected `namespace="<its namespace>"`
    matcher, `continue: true`, and the receiver name
    `<namespace>/<name>/<receiver>`.
  - `amtool` is in the Alertmanager image; `amtool alert query` hides
    silenced alerts unless `--silenced` is given.
  - Prometheus 3.15 returns an `infos` note for `rate()` on a metric whose
    name does not end in `_total`/`_sum`/`_count`/`_bucket`.
- **Facts still to check before writing them down:** the Jaeger 2.x image
  and its OTLP ports; the filelog receiver's container parser and the count
  connector on Collector contrib 0.162.0; which Argo CD and Flux metrics give
  deployment counts; the podinfo OTLP endpoint variables.
- **The proof is a measurement.** A fix is proven with a PromQL query that
  returns the expected value, a target that shows `up == 1`, an alert that
  reaches its receiver, a trace visible in Jaeger with spans from both
  services, or a pod that is `Running` and serves a `200` to `shuttle`.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Course plan (sections, modules, objectives, playground needs) | `.astrona/blueprint.yaml` |
| Overview, sections and modules tables, how to run things | `README.md` |
| Introduction (see "Every course starts with an Introduction") | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-01/` (`question.md`, `solution.md`, `prerequisites.md`, `bootstrap/`, `manifests/`, `solution/`, `testing/`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` points at `question.md` and `solution.md` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `prerequisites.md` | What the learner needs before starting |
| `question.md` | The exam-style task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough with real output |
| `bootstrap/` | Tool install (for example `01-install-prometheus.sh`) and the starting state (`02-seed-workloads.sh`) |
| `manifests/` | `lab-start.yaml` (workloads) and any faulty configuration the learner must fix |
| `solution/apply.sh`, `solution/solution.yaml` | Reference end state, applied only by `astrona test` |
| `testing/` | Helpers `astrona test` runs (for example `wait-for-prometheus.sh`) |
| `validation/validate-*.sh` | Behavioural grading, one script per check (for example `validate-target-up.sh`, `validate-alert-firing.sh`) |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS020`, domain
`Observability and Operations`, weight `20`) and one entry per section under
`modules:` (`module-intro`, then `module-010`, `module-020` and so on). Each
section's `content` lists, in order: the section `README.md`, then for each
module its landing page, its parts, and right after the part a lab tests, a
`Question` reading (`labs/lab-01/question.md`) followed by the `type: lab`
entry; the module's closing page comes last. The section capstone closes the
section. Playgrounds are not listed: the landing page's
`<!-- astrona:playground -->` marker shows them.

Every `type: lab` entry (module labs and capstones) carries these fields, in
this order:

```yaml
      - type: reading
        title: Question
        path: sections/section-010/module-01/labs/lab-01/question.md
      - type: lab
        title: "Get A Workload Scraped With A ServiceMonitor Lab"
        path: sections/section-010/module-01/labs/lab-01
        difficulty: beginner
        estimated_duration: 15m
        topic: metrics
        task_kind: troubleshooting
        tags: [prometheus, servicemonitor, scrape-target, label-selector]
        learning_goals:
          - Find why the scout target does not appear in Prometheus
          - Fix the ServiceMonitor so its selector and port match the Service
          - Prove the fix with up == 1 for every scout endpoint
        resources:
          - name: "Prometheus Operator: ServiceMonitor"
            url: https://prometheus-operator.dev/docs/developer/getting-started/
```

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`, `45m`.
- `topic`: exactly one of `metrics`, `alerting`, `dashboards`, `logging`,
  `tracing`, `delivery-metrics`, `efficiency`, `workload-incidents`,
  `platform-incidents`.
- `task_kind`: exactly one of `build` (write the configuration from
  scratch), `troubleshooting` (find and fix what is broken) or `migration`
  (move a working setup to another mode or layout). The platform filters labs
  by it, so it is a field of its own, never a tag.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb, saying
  what the learner proves in this lab.
- `resources`: 1 to 4 documentation pages, each with a `name` and a `url`
  that loads. This is the **only** place outside links are allowed: the
  platform shows them as optional further reading next to the lab.

**Tag list** (lower case, hyphens, never synonyms):

- Metrics: `prometheus`, `servicemonitor`, `podmonitor`, `scrape-target`,
  `label-selector`, `promql`, `rate`, `histogram-quantile`, `recording-rule`
- Alerting: `prometheusrule`, `alerting-rule`, `alertmanager`,
  `alertmanager-route`, `silence`
- Dashboards and logs: `grafana`, `grafana-dashboard`, `data-source`,
  `otel-collector`, `filelog-receiver`, `k8sattributes`, `count-connector`,
  `kubectl-logs`
- Tracing: `opentelemetry`, `otlp`, `collector-pipeline`,
  `instrumentation`, `auto-instrumentation`, `jaeger`, `context-propagation`
- Delivery and efficiency: `dora-metrics`, `deployment-frequency`,
  `lead-time`, `change-failure-rate`, `time-to-restore`, `sli`, `slo`,
  `error-budget`, `resource-efficiency`, `metrics-server`
- Workload incidents: `pending`, `crashloopbackoff`, `oomkilled`,
  `imagepullbackoff`, `events`, `probes`
- Platform incidents: `admission-webhook`, `controller-down`, `stuck-sync`,
  `certificate-expiry`, `argocd`, `flux`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-01/playground
astrona destroy ats-020-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-020-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names: a playground is `ats-020-playground-<section>-<module>`, a module lab
is `ats-020-lab-<section>-<module>` and a capstone is
`ats-020-capstone-<section>`; keep those names. A second lab in a module
takes `ats-020-lab-<section>-<module>-<lab>`, for example
`ats-020-lab-010-02-02`, so two labs never share a name. Lab bootstrap
scripts do not pin a kube context: astrona sets `KUBECONFIG` for the lab, and
`astrona test` runs on a cluster with a different name. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **behaviour**, not just that an object exists: query
Prometheus for the target or the alert, read the trace from the Jaeger API,
or send a real request from `shuttle`. Graders also reject the plausible but
wrong fix (deleting the alerting rule so nothing fires, removing a memory
limit instead of sizing it, deleting a failing webhook configuration instead
of fixing its Service, setting `failurePolicy: Ignore` to hide the error). A
lab's `question.md` and `solution.md` must match what its `validation/`
scripts actually check.

Test clusters on the maintainer's machine: one at a time. Podman has 10 GiB
and also runs the platform stack; parallel clusters run it out of memory.
Section 040 (GitOps controller plus Gitea plus Prometheus) is the heaviest.
Never touch clusters you did not create.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

- **Prometheus:**
  [querying basics](https://prometheus.io/docs/prometheus/latest/querying/basics/),
  [query functions](https://prometheus.io/docs/prometheus/latest/querying/functions/),
  [alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/),
  [recording rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/),
  [Alertmanager configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- **Prometheus Operator:**
  [getting started](https://prometheus-operator.dev/docs/developer/getting-started/),
  [API reference](https://prometheus-operator.dev/docs/api-reference/api/),
  [kube-prometheus-stack chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- **Grafana:**
  [Grafana provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- **OpenTelemetry:**
  [Collector configuration](https://opentelemetry.io/docs/collector/configuration/),
  [Operator](https://opentelemetry.io/docs/platforms/kubernetes/operator/),
  [auto-instrumentation](https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/),
  [filelog receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver)
- **Jaeger:** [Jaeger documentation](https://www.jaegertracing.io/docs/latest/)
- **Kubernetes debugging:**
  [debug pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/),
  [debug running pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/),
  [debug a cluster](https://kubernetes.io/docs/tasks/debug/debug-cluster/),
  [resource metrics pipeline](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/),
  [admission webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- **Delivery metrics:** [DORA metrics](https://dora.dev/guides/dora-metrics-four-keys/),
  [Argo CD metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/),
  [Flux monitoring](https://fluxcd.io/flux/monitoring/)
- **The exam itself:**
  [CNPE certification page](https://training.linuxfoundation.org/certification/certified-cloud-native-platform-engineer-cnpe/)
  lists the competencies and the 20% weight;
  [Important Instructions: CNPE](https://docs.linuxfoundation.org/tc-docs/certification/important-instructions-cnpe)
  gives the Kubernetes version, the featured tools and the exam environment.

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository: planning
(`domain-plan`), creating the tree (`domain-scaffold`), building modules
(`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds (`lab`),
lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).

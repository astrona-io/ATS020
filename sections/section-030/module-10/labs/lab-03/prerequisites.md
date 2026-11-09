# Prerequisites

You need `astrona`, `kubectl`, `curl` and `jq` on the terminal where you start
the lab. Bootstrap checks the last three tools before applying workloads.
You need a browser for the Jaeger user interface (UI), which displays traces.
The query application programming interface (API) also supports the search task.

A span records one timed operation. A trace groups spans with the same trace
identifier (ID). A span has a status, which is `UNSET`, `OK` or `ERROR`, and
can carry span events, which are timestamped records inside the span. Know how
to filter JSON with `jq`, and how to use `kubectl port-forward`,
`kubectl set env` and `kubectl rollout status`.

The lab supplies Kubernetes 1.35.8, Jaeger 2.23.0 and three Python trace
emitters. It installs no packages into the running containers.

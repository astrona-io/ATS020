# Prerequisites

Allow 35 minutes. Be able to write a PromQL `rate()` with `sum by`, a LogQL stream
selector with a line filter, and use the Grafana data source and dashboard
screens or APIs. Know `kubectl set env` and `kubectl rollout status`.

The terminal has kubectl, curl and jq. Grafana is the Service `kps-grafana` in
`monitoring` on port `80`. Prometheus is the Service `kps-prometheus` in
`monitoring` on port `9090`. Loki is the Service `loki` in `logging` on port
`3100`. The Deployment `shuttle` in `starfleet` sends requests.

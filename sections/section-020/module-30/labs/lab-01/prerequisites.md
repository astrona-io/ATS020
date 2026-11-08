# Prerequisites

Allow 25 minutes. Be able to use `kubectl port-forward`, `kubectl get` and
`kubectl scale`, and to read JSON with `jq`. Know how a Deployment and a
StatefulSet name their Pods.

The terminal has kubectl, curl and jq. Grafana is the Service `kps-grafana` in
`monitoring` on port `80`, with the user `admin` and the password `starfleet`.
Loki is the Service `loki` in `logging` on port `3100`. Loki stores the logs of
`outpost` and `starfleet` with the labels `namespace`, `pod` and `container`.

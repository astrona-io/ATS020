#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring patch prometheusrule scout-queries --type=json -p '[{"op": "replace", "path": "/spec/groups/0/rules/0/expr", "value": "sum(rate(http_requests_total{namespace=\"starfleet\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{namespace=\"starfleet\"}[5m]))"}]'

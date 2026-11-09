#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring patch prometheusrule scout-queries --type=json -p '[{"op": "replace", "path": "/spec/groups/0/rules/1/expr", "value": "histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"starfleet\"}[5m])))"}]'

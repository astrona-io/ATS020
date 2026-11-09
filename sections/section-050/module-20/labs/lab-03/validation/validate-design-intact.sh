#!/usr/bin/env bash
set -euo pipefail
for target in 'starfleet deployment scout' 'starfleet servicemonitor scout' 'starfleet prometheusrule scout-alerts' 'monitoring deployment kps-operator' 'monitoring prometheus kps-prometheus'; do
  set -- $target
  kubectl -n "$1" get "$2" "$3" >/dev/null || { echo "FAIL: missing $target"; exit 1; }
done
echo 'PASS: workloads and monitoring resources are present'

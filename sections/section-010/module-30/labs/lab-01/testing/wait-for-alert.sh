#!/usr/bin/env bash
set -euo pipefail
for attempt in $(seq 1 84); do
  if kubectl -n monitoring logs deploy/alert-receiver | grep -q 'firing ScoutErrorRate namespace=starfleet severity=warning'; then
    exit 0
  fi
  sleep 5
done
echo 'No ScoutErrorRate notification arrived' >&2
exit 1

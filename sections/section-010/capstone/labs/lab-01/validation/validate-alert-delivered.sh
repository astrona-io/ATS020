#!/usr/bin/env bash
# Grader: Alertmanager really sent the alert to the receiver. The alert-receiver
# pod prints one line for each alert in each notification, so the log must hold
# a "firing ScoutHighErrorRatio namespace=frontier" line. Retries, because the
# group wait, the group interval and the retry after a failed post add delay.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

for attempt in $(seq 1 72); do
  if kubectl -n monitoring logs deploy/alert-receiver 2>/dev/null | grep -q 'firing ScoutHighErrorRatio namespace=frontier'; then
    echo "PASS: the alert-receiver logged a firing notification for ScoutHighErrorRatio in frontier"
    exit 0
  fi
  sleep 5
done
fail "the alert-receiver has no 'firing ScoutHighErrorRatio namespace=frontier' line; check the AlertmanagerConfig route and the receiver URL"

#!/usr/bin/env bash
# Grader: Prometheus scrapes every ready scout endpoint through the job of the
# ServiceMonitor scout (scrape pool serviceMonitor/starfleet/scout/0), and
# every up series is 1. The number of targets is compared with the number of
# ready endpoint addresses in the cluster, so a partial fix fails. Retries,
# because a changed monitor reaches Prometheus after about 60 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/$1" 2>/dev/null
}

READY="$(kubectl -n starfleet get endpoints scout -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w | tr -d ' ')"
[ "${READY:-0}" -ge 1 ] || fail "the Service scout has no ready endpoints; the workload must stay running"

UP=0
for attempt in $(seq 1 36); do
  UP="$(api 'targets?state=active' | jq '[.data.activeTargets[]
      | select(.scrapePool == "serviceMonitor/starfleet/scout/0" and .health == "up")] | length' 2>/dev/null)"
  UP="${UP:-0}"
  if [ "$UP" = "$READY" ]; then
    SERIES="$(api 'query?query=up%7Bjob%3D%22scout%22%2Cnamespace%3D%22starfleet%22%7D' \
      | jq '[.data.result[] | select(.value[1] == "1")] | length' 2>/dev/null)"
    if [ "${SERIES:-0}" = "$READY" ]; then
      echo "PASS: $SERIES of $READY scout endpoints have up == 1"
      exit 0
    fi
  fi
  sleep 5
done
fail "Prometheus has $UP healthy scout targets in the pool serviceMonitor/starfleet/scout/0, expected $READY (one for each ready endpoint)"

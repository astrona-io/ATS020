#!/usr/bin/env bash
# Grader: Prometheus scrapes every ready scout endpoint through the job of the
# ServiceMonitor scout (scrape pool serviceMonitor/starfleet/scout/0), and
# every up series is 1. The number of targets is compared with the number of
# ready endpoint addresses in the cluster, so a partial fix fails. Retries,
# because a changed monitor reaches Prometheus after about 60 seconds.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# The design must stay (checked first, before the task): the Prometheus
# resource, the Service scout and the label release kps are unchanged.
SELECTOR="$(kubectl -n monitoring get prometheus kps-prometheus -o jsonpath='{.spec.serviceMonitorSelector.matchLabels.release}' 2>/dev/null)"
[ "$SELECTOR" = "kps" ] || fail "the Prometheus resource must still select release: kps (found '${SELECTOR:-none}'); fix the ServiceMonitor, not the Prometheus resource"

PORT_NAME="$(kubectl -n starfleet get service scout -o jsonpath='{.spec.ports[0].name}' 2>/dev/null)"
[ "$PORT_NAME" = "http" ] || fail "the Service scout must still name its port http (found '${PORT_NAME:-none}'); fix the ServiceMonitor, not the Service"

SVC_LABEL="$(kubectl -n starfleet get service scout -o jsonpath='{.metadata.labels.app}' 2>/dev/null)"
[ "$SVC_LABEL" = "scout" ] || fail "the Service scout must still have the label app: scout"

kubectl -n starfleet get servicemonitor scout >/dev/null 2>&1 || fail "the ServiceMonitor scout in starfleet is missing"
LABEL="$(kubectl -n starfleet get servicemonitor scout -o jsonpath='{.metadata.labels.release}' 2>/dev/null)"
[ "$LABEL" = "kps" ] || fail "the ServiceMonitor scout must have the label release: kps (found '${LABEL:-none}')"

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

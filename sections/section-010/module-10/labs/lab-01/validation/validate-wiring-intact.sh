#!/usr/bin/env bash
# Grader: the fix is in the ServiceMonitor, not around it. The Prometheus
# resource still selects release: kps, the Service scout still names its port
# http and selects app: scout, and the ServiceMonitor scout still exists in
# starfleet with the label that Prometheus selects. Widening the Prometheus
# selector to {} or renaming the Service port would make targets appear, and
# both are rejected here.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

SELECTOR="$(kubectl -n monitoring get prometheus kps-prometheus -o jsonpath='{.spec.serviceMonitorSelector.matchLabels.release}' 2>/dev/null)"
[ "$SELECTOR" = "kps" ] || fail "the Prometheus resource must still select release: kps (found '${SELECTOR:-none}'); fix the ServiceMonitor, not the Prometheus resource"

PORT_NAME="$(kubectl -n starfleet get service scout -o jsonpath='{.spec.ports[0].name}' 2>/dev/null)"
[ "$PORT_NAME" = "http" ] || fail "the Service scout must still name its port http (found '${PORT_NAME:-none}'); fix the ServiceMonitor, not the Service"

SVC_LABEL="$(kubectl -n starfleet get service scout -o jsonpath='{.metadata.labels.app}' 2>/dev/null)"
[ "$SVC_LABEL" = "scout" ] || fail "the Service scout must still have the label app: scout"

kubectl -n starfleet get servicemonitor scout >/dev/null 2>&1 || fail "the ServiceMonitor scout in starfleet is missing"
LABEL="$(kubectl -n starfleet get servicemonitor scout -o jsonpath='{.metadata.labels.release}' 2>/dev/null)"
[ "$LABEL" = "kps" ] || fail "the ServiceMonitor scout must have the label release: kps (found '${LABEL:-none}')"

echo "PASS: the ServiceMonitor scout carries release: kps and the Prometheus resource and the Service are unchanged"

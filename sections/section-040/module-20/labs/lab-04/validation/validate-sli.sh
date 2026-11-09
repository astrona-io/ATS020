#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
rules=$(kubectl -n monitoring get prometheusrule scout-sli -o json 2>/dev/null) || fail 'create the scout-sli recording rules'
printf '%s' "$rules" | jq -e '[.spec.groups[].rules[] | select(.record == "scout:sli:ratio_rate5m" or .record == "scout:sli:ratio_rate1h") | .expr | contains("http_requests_total") and contains("rate(")] | length == 2 and all' >/dev/null || fail 'derive both SLIs from the request counters'
query() {
 local q
 q=$(jq -rn --arg q "$1" '$q | @uri')
 kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=$q" | jq -r '.data.result[0].value[1] // empty'
}
for attempt in $(seq 1 60); do
 actual=$(query 'scout:sli:ratio_rate5m'); long=$(query 'scout:sli:ratio_rate1h')
 expected=$(query 'sum(rate(http_requests_total{namespace="starfleet",container="scout",status!~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[5m]))')
 expected_long=$(query 'sum(rate(http_requests_total{namespace="starfleet",container="scout",status!~"5.."}[1h])) / sum(rate(http_requests_total{namespace="starfleet",container="scout"}[1h]))')
 budget=$(query 'scout:error_budget_remaining:ratio1h')
 if python3 - "$actual" "$long" "$expected" "$expected_long" "$budget" <<'CHECK'
import math, sys
try:
 a, b, e, f, budget = map(float, sys.argv[1:])
 assert all(math.isfinite(v) for v in [a,b,e,f,budget])
 assert 0.85 < e < 0.99 and 0.85 < f < 0.99
 assert abs(a-e) < 0.005 and abs(b-f) < 0.005
 assert abs(budget - (1-(1-f)/0.01)) < 0.5
except (ValueError, AssertionError): sys.exit(1)
CHECK
 then echo 'PASS: both SLIs and the remaining budget match live request rates'; exit 0; fi
 sleep 5
done
fail 'the SLI or error budget differs from the live request rates'

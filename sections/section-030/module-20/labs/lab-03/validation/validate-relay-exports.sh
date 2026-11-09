#!/usr/bin/env bash
# Read recent relay spans through the API server proxy; no port-forward is needed.
set -euo pipefail
for attempt in $(seq 1 48); do
  start=$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=3)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
  if kubectl get --raw "/api/v1/namespaces/observability/services/jaeger:16686/proxy/api/v3/traces?query.service_name=relay&query.start_time_min=${start}&query.start_time_max=2100-01-01T00:00:00Z&query.search_depth=5" --request-timeout=10s 2>/dev/null |
      jq -e 'any(.result.resourceSpans[]?;
        any(.resource.attributes[]?; .key == "service.name" and .value.stringValue == "relay")
        and any(.scopeSpans[]?.spans[]?; .traceId != null and .spanId != null))' >/dev/null; then
    echo "PASS: Jaeger receives recent spans from relay"
    exit 0
  fi
  sleep 5
done
echo "FAIL: no recent relay spans in Jaeger; check agent startup, its exporter endpoint, and the Collector" >&2
exit 1

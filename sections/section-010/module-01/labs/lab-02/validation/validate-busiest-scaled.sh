#!/usr/bin/env bash
# Read the winner from Prometheus, then compare desired and ready replicas.
set -euo pipefail
fail() { echo "FAIL: busiest-scaled: $*" >&2; exit 1; }
api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/$1"
}
for attempt in $(seq 1 36); do
  result="$(api 'query?query=sum%20by%20%28deployment%29%20%28starfleet_queue_items%7Bjob%3D%22starfleet-pods%22%2Cnamespace%3D%22starfleet%22%7D%29' 2>/dev/null || true)"
  if jq -e '.status == "success" and (.data.result | length) == 2
    and ([.data.result[].metric.deployment] | sort) == ["probe","scout"]' <<<"$result" >/dev/null 2>&1; then
    ranked="$(jq -c '.data.result | sort_by(.value[1] | tonumber) | reverse' <<<"$result")"
    if jq -e '(.[0].value[1] | tonumber) > (.[1].value[1] | tonumber)' <<<"$ranked" >/dev/null; then
      winner="$(jq -r '.[0].metric.deployment' <<<"$ranked")"
      deployments="$(kubectl -n starfleet get deploy scout probe shuttle -o json)" || fail "cannot read Deployments"
      # Keep the exercise inputs intact; only replica counts may change.
      if jq -e --arg winner "$winner" '
        all(.items[];
          .metadata.name as $name |
          .spec.template.metadata.labels.app == $name and
          .spec.template.metadata.labels.telemetry ==
            (if $name == "scout" then "primary" elif $name == "probe" then "reserve" else "disabled" end) and
          .spec.template.spec.containers[0].image == "python:3.13.18-alpine3.24" and
          .spec.template.spec.containers[0].env == [{"name":"QUEUE_ITEMS","value":
            (if $name == "scout" then "12" elif $name == "probe" then "90" else "200" end)}] and
          .spec.replicas == (if $name == $winner then 3 else 1 end) and
          .status.readyReplicas == .spec.replicas and
          .status.updatedReplicas == .spec.replicas and
          .status.observedGeneration >= .metadata.generation)
      ' <<<"$deployments" >/dev/null; then
        echo "PASS: busiest-scaled: $winner has three ready replicas; other Deployments have one"
        exit 0
      fi
    fi
  fi
  sleep 5
done
fail "query must return both workloads with a clear winner; scale only that Deployment to three ready replicas and keep the metric inputs unchanged"

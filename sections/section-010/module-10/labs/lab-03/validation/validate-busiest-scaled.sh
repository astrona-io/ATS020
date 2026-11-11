#!/usr/bin/env bash
# Read the winner from Prometheus, compare desired and ready replicas, then
# prove every ready primary and reserve Pod, the new replicas included, is a
# healthy discovered target.
set -euo pipefail
fail() { echo "FAIL: busiest-scaled: $*" >&2; exit 1; }
api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/$1"
}

# Succeeds when only the Deployment with the highest queue total runs three
# ready replicas, and the exercise inputs are unchanged.
check_scaled() {
  local result ranked winner deployments
  result="$(api 'query?query=sum%20by%20%28deployment%29%20%28starfleet_queue_items%7Bjob%3D%22starfleet-pods%22%2Cnamespace%3D%22starfleet%22%7D%29' 2>/dev/null || true)"
  jq -e '.status == "success" and (.data.result | length) == 2
    and ([.data.result[].metric.deployment] | sort) == ["probe","scout"]' <<<"$result" >/dev/null 2>&1 || return 1
  ranked="$(jq -c '.data.result | sort_by(.value[1] | tonumber) | reverse' <<<"$result")"
  jq -e '(.[0].value[1] | tonumber) > (.[1].value[1] | tonumber)' <<<"$ranked" >/dev/null || return 1
  winner="$(jq -r '.[0].metric.deployment' <<<"$ranked")"
  deployments="$(kubectl -n starfleet get deploy scout probe shuttle -o json)" || return 1
  # Keep the exercise inputs intact; only replica counts may change.
  jq -e --arg winner "$winner" '
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
  ' <<<"$deployments" >/dev/null
}

# Succeeds when the active starfleet-pods targets are exactly the ready
# primary and reserve Pods, found by dynamic Pod discovery.
check_targets() {
  local pods expected targets actual total count discovered loaded
  pods="$(kubectl -n starfleet get pods -o json)" || return 1
  expected="$(jq -c '[.items[]
    | select(.metadata.labels.telemetry == "primary" or .metadata.labels.telemetry == "reserve")
    | select(.metadata.deletionTimestamp == null)
    | select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))
    | {instance: (.status.podIP + ":8080"), pod: .metadata.name,
       deployment: .metadata.labels.app, namespace: .metadata.namespace}]
    | sort_by(.instance)' <<<"$pods")"
  jq -e 'length >= 2 and (map(.deployment) | unique | sort) == ["probe","scout"]' <<<"$expected" >/dev/null || return 1
  targets="$(api 'targets?state=active' 2>/dev/null || true)"
  actual="$(jq -ec '[.data.activeTargets[] | select(.scrapePool == "starfleet-pods")
    | select(.health == "up") | .labels
    | {instance, pod, deployment, namespace}] | sort_by(.instance)' <<<"$targets" 2>/dev/null || true)"
  total="$(jq -r '[.data.activeTargets[] | select(.scrapePool == "starfleet-pods")] | length' <<<"$targets" 2>/dev/null || true)"
  count="$(jq length <<<"$expected")"
  # Discovered Pod labels rule out replacing discovery with static targets.
  discovered="$(jq -r '[.data.activeTargets[] | select(.scrapePool == "starfleet-pods")
    | select(.discoveredLabels.__meta_kubernetes_pod_name != null)] | length' <<<"$targets" 2>/dev/null || true)"
  loaded="$(api 'status/config' 2>/dev/null || true)"
  [ "$actual" = "$expected" ] && [ "$total" = "$count" ] && [ "$discovered" = "$count" ] &&
    jq -e '.status == "success" and (.data.yaml |
      contains("kubernetes_sd_configs:") and contains("role: pod") and
      contains("relabel_configs:") and contains("action: keep") and
      contains("__meta_kubernetes_pod_label_telemetry") and
      contains("__meta_kubernetes_pod_container_port_name") and
      contains("__meta_kubernetes_pod_ready"))' <<<"$loaded" >/dev/null 2>&1
}

for attempt in $(seq 1 36); do
  if check_scaled && check_targets; then
    echo "PASS: busiest-scaled: only the busiest Deployment has three ready replicas, and every ready primary and reserve Pod is a healthy target"
    exit 0
  fi
  sleep 5
done
fail "scale only the Deployment with the highest queue total to three ready replicas, keep the metric inputs unchanged, and keep dynamic discovery so every ready primary and reserve Pod is a healthy target"

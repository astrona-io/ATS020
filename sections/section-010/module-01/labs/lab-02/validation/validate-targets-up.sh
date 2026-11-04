#!/usr/bin/env bash
# Compare active target addresses with the ready Pods, including after scaling.
set -euo pipefail
fail() { echo "FAIL: targets-up: $*" >&2; exit 1; }
api() {
  kubectl get --raw "/api/v1/namespaces/monitoring/services/prometheus-raw:9090/proxy/api/v1/$1"
}
for attempt in $(seq 1 36); do
  pods="$(kubectl -n starfleet get pods -o json)" || fail "cannot read Pods"
  expected="$(jq -c '[.items[]
    | select(.metadata.labels.telemetry == "primary" or .metadata.labels.telemetry == "reserve")
    | select(.metadata.deletionTimestamp == null)
    | select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))
    | {instance: (.status.podIP + ":8080"), pod: .metadata.name,
       deployment: .metadata.labels.app, namespace: .metadata.namespace}]
    | sort_by(.instance)' <<<"$pods")"
  if jq -e 'length >= 2 and (map(.deployment) | unique | sort) == ["probe","scout"]' <<<"$expected" >/dev/null; then
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
    if [ "$actual" = "$expected" ] && [ "$total" = "$count" ] && [ "$discovered" = "$count" ] &&
      jq -e '.status == "success" and (.data.yaml |
        contains("kubernetes_sd_configs:") and contains("role: pod") and
        contains("relabel_configs:") and contains("action: keep") and
        contains("__meta_kubernetes_pod_label_telemetry") and
        contains("__meta_kubernetes_pod_container_port_name") and
        contains("__meta_kubernetes_pod_ready"))' <<<"$loaded" >/dev/null 2>&1; then
      echo "PASS: targets-up: every selected ready Pod is scraped; disabled Pods are excluded"
      exit 0
    fi
  fi
  sleep 5
done
fail "expected one healthy starfleet-pods target per primary or reserve Pod, and no others; check the loaded configuration"

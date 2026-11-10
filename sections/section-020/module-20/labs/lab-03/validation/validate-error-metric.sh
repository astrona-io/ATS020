#!/usr/bin/env bash
# Grades the behaviour: the metric made from log lines must carry the labels
# that name the workload, and it must keep rising while probe logs errors.
# Two samples taken 45 seconds apart must differ.
set -u
fail() { echo "FAIL: $*"; exit 1; }

# The design must stay (checked first): the Collector keeps file_log,
# k8s_attributes, the count connector and DaemonSet mode, and its service
# account gets read access to pods and nothing wider. This rejects removing
# the processor or binding cluster-admin.
SA="system:serviceaccount:monitoring:logs-collector"

# The pipeline must still read files, add metadata and count.
pipeline=$(kubectl -n monitoring get opentelemetrycollector logs -o json 2>/dev/null) \
  || fail "the OpenTelemetryCollector logs in monitoring does not exist"
echo "$pipeline" | jq -e '.spec.config.service.pipelines.logs.receivers | index("file_log")' >/dev/null \
  || fail "the logs pipeline no longer uses the file_log receiver"
echo "$pipeline" | jq -e '.spec.config.service.pipelines.logs.processors | index("k8s_attributes")' >/dev/null \
  || fail "the logs pipeline no longer uses the k8s_attributes processor; fix the permission instead of removing the processor"
echo "$pipeline" | jq -e '.spec.config.service.pipelines.logs.exporters | index("count")' >/dev/null \
  || fail "the logs pipeline no longer sends records to the count connector"
[[ "$(echo "$pipeline" | jq -r '.spec.mode')" == "daemonset" ]] \
  || fail "the Collector must stay a DaemonSet so it reads the log files on every node"

# Read access to pods: yes. Anything wider: no.
[[ "$(kubectl auth can-i list pods --all-namespaces --as="$SA")" == "yes" ]] \
  || fail "the Collector's service account cannot list pods in all namespaces"
[[ "$(kubectl auth can-i watch pods --all-namespaces --as="$SA")" == "yes" ]] \
  || fail "the Collector's service account cannot watch pods in all namespaces"
for denied in "get secrets" "delete pods" "create pods" "list nodes"; do
  [[ "$(kubectl auth can-i $denied --all-namespaces --as="$SA" 2>/dev/null)" == "no" ]] \
    || fail "the Collector's service account can '$denied'; it needs read access to pods and nothing more"
done

# No binding to cluster-admin and no wildcard in the role it uses.
bad=$(kubectl get clusterrolebinding -o json | jq -r --arg ns monitoring '
  .items[]
  | select(any(.subjects[]?; .kind=="ServiceAccount" and .name=="logs-collector" and .namespace==$ns))
  | select(.roleRef.name=="cluster-admin" or .roleRef.name=="admin" or .roleRef.name=="edit")
  | .metadata.name')
[[ -z "$bad" ]] || fail "the Collector's service account is bound to a broad role through $bad"
wild=$(kubectl get clusterrole logs-collector -o json | jq -r '[.rules[] | select((.verbs[]?=="*") or (.resources[]?=="*") or (.apiGroups[]?=="*"))] | length')
[[ "$wild" == "0" ]] || fail "the ClusterRole logs-collector contains a wildcard"


PROM='/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy'
SELECTOR='log_error_lines_total{k8s_namespace_name="outpost",k8s_deployment_name="probe"}'

prom_sum() {
  kubectl get --raw "$PROM/api/v1/query?query=$(jq -rn --arg q "sum($1)" '$q|@uri')" 2>/dev/null |
    jq -r '.data.result[0].value[1] // empty'
}

first=""
for _ in $(seq 1 36); do
  first=$(prom_sum "$SELECTOR")
  [[ -n "$first" ]] && break
  sleep 5
done
[[ -n "$first" ]] || fail "Prometheus has no series $SELECTOR; the labels k8s_namespace_name and k8s_deployment_name are missing or the target is not scraped"

sleep 45
second=$(prom_sum "$SELECTOR")
[[ -n "$second" ]] || fail "the series $SELECTOR disappeared"
awk -v a="$first" -v b="$second" 'BEGIN { exit !(b > a) }' \
  || fail "log_error_lines_total did not rise in 45 seconds (first $first, second $second); probe logs an error every 4 seconds"
echo "PASS: log_error_lines_total for probe in outpost rose from $first to $second"

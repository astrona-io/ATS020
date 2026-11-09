#!/usr/bin/env bash
# Rejects the plausible wrong fixes: giving the Collector cluster-admin or a
# wildcard role, removing the k8s_attributes processor from the logs pipeline,
# or counting without the file_log receiver. The Collector must still read
# the files, add metadata, and have only read access to pods.
set -u
fail() { echo "FAIL: $*"; exit 1; }

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

echo "PASS: the pipeline is intact and the Collector has read-only access to pods"

#!/usr/bin/env bash
# Works out from Loki which controllers in outpost wrote ERROR lines, then checks
# that exactly those controllers run no Pods and that every other controller in
# outpost still runs.
set -u
fail() { echo "FAIL: $*"; exit 1; }

LOKI_API="/api/v1/namespaces/logging/services/loki:3100/proxy/loki/api/v1"
uri() { jq -rn --arg value "$1" '$value | @uri'; }

query='sum by (pod) (count_over_time({namespace="outpost"} |= "ERROR" [6h]))'
pods=$(kubectl get --raw "$LOKI_API/query?query=$(uri "$query")" 2>/dev/null | jq -r '.data.result[].metric.pod') ||
  fail "cannot query Loki"
[ -n "$pods" ] || fail "Loki holds no ERROR lines for outpost yet"

failing=" "
while read -r pod; do
  if [[ "$pod" =~ ^(.+)-[a-z0-9]+-[a-z0-9]{5}$ ]]; then
    failing+="Deployment/${BASH_REMATCH[1]} "
  elif [[ "$pod" =~ ^(.+)-[0-9]+$ ]]; then
    failing+="StatefulSet/${BASH_REMATCH[1]} "
  fi
done <<< "$pods"

controllers=$(kubectl -n outpost get deployments,statefulsets -o json | jq -r \
  '.items[] | "\(.kind)/\(.metadata.name) \(.spec.replicas // 0) \(.status.replicas // 0) \(.status.readyReplicas // 0)"') ||
  fail "cannot list the controllers in outpost"

for controller in $failing; do
  grep -q "^$controller " <<< "$controllers" || fail "a controller was deleted; scale controllers instead of deleting them"
done

still_running=0
while read -r controller desired current ready; do
  case "$failing" in
    *" $controller "*)
      if [ "$desired" -ne 0 ] || [ "$current" -ne 0 ]; then
        still_running=$((still_running + 1))
      fi
      ;;
    *)
      if [ "$desired" -lt 1 ] || [ "$ready" -lt 1 ]; then
        fail "$controller wrote no ERROR line, so it must keep running"
      fi
      ;;
  esac
done <<< "$controllers"
[ "$still_running" -eq 0 ] || fail "$still_running controller(s) whose Pods wrote ERROR lines still run Pods"
echo "PASS: every controller that wrote ERROR lines is at 0 replicas and the others still run"

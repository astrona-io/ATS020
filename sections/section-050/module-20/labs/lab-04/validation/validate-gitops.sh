#!/usr/bin/env bash
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
app=$(kubectl -n argocd get application scout -o json)
printf '%s' "$app" | jq -e '.spec.source.path == "scout" and .spec.source.targetRevision == "main" and .spec.source.repoURL == "http://gitea.gitea.svc.cluster.local:3000/starfleet/starfleet-deploy.git" and .spec.destination.namespace == "starfleet" and .spec.syncPolicy.automated.prune == true' >/dev/null || fail 'restore the original Git source and keep automated sync'
revision=$(kubectl -n gitea exec deploy/gitea -- git -C /tmp/work rev-parse HEAD)
for attempt in $(seq 1 60); do
 app=$(kubectl -n argocd get application scout -o json)
 if printf '%s' "$app" | jq -e --arg revision "$revision" '.status.sync.status == "Synced" and .status.health.status == "Healthy" and .status.sync.revision == $revision and ([.status.conditions[]? | select(.type | endswith("Error"))] | length == 0)' >/dev/null; then
  kubectl -n starfleet rollout status deployment/scout --timeout=60s
  code=$(kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}' http://scout:9898/)
  [ "$code" = 200 ] || fail 'scout does not serve HTTP 200'
  echo 'PASS: Git reconciliation and the deployed workload are healthy'; exit 0
 fi
 sleep 5
done
fail 'the Application has not recovered'

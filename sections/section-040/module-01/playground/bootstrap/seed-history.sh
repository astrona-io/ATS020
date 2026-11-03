#!/usr/bin/env bash
# Makes the delivery history for the DORA playground.
#
#   seed-history.sh init     create the Gitea user and the repository
#   seed-history.sh history  push ten commits and wait for Argo CD after each
#
# Git work runs inside the Gitea pod (it has git). Each commit gets a commit
# time some minutes before the push, so lead time is not zero. Commits 3 and 7
# use an image tag that does not exist (a bad change). Commits 4 and 8 put the
# working tag back (the restore).
#
# The script makes the history deterministic on a slow or loaded machine:
#   - A good commit gets a long progressDeadlineSeconds (300), so a slow but
#     healthy rollout stays Progressing and never turns Degraded by accident.
#     Only the two bad commits use 30 seconds, so exactly two Degraded
#     episodes exist.
#   - After each sync the script waits until Prometheus has scraped the new
#     value of argocd_app_sync_total (and, for a bad commit, the Degraded
#     health). A fixed sleep could let two syncs pass between two scrapes, so
#     the first sample of the counter would be 2 and increase() would be lower.
set -euo pipefail

GITEA_USER="starfleet"
GITEA_PASSWORD="starfleet-pass-1"
REPO="starfleet-deploy"

in_gitea() { kubectl -n gitea exec -i deploy/gitea -- sh -c "$1"; }

if [ "${1:-}" = "init" ]; then
  in_gitea "gitea admin user create --admin --username $GITEA_USER --password $GITEA_PASSWORD --email starfleet@example.com --must-change-password=false" >/dev/null
  in_gitea "curl -fsS -u $GITEA_USER:$GITEA_PASSWORD -X POST -H 'Content-Type: application/json' -d '{\"name\":\"$REPO\",\"private\":false,\"default_branch\":\"main\",\"auto_init\":false}' http://localhost:3000/api/v1/user/repos" >/dev/null
  in_gitea "rm -rf /tmp/work && git init -q -b main /tmp/work && cd /tmp/work && git config user.name 'Starfleet Dev' && git config user.email dev@example.com && git remote add origin http://$GITEA_USER:$GITEA_PASSWORD@localhost:3000/$GITEA_USER/$REPO.git"
  exit 0
fi

# push_commit <message> <minutes before the push> <image tag> <ui message> <replicas> <deadline seconds>
push_commit() {
  local message="$1" minutes="$2" tag="$3" ui="$4" replicas="$5" deadline="$6"
  in_gitea "cd /tmp/work && mkdir -p scout && cat > scout/scout.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scout
  namespace: starfleet
  labels:
    app: scout
spec:
  replicas: $replicas
  progressDeadlineSeconds: $deadline
  selector:
    matchLabels:
      app: scout
  template:
    metadata:
      labels:
        app: scout
    spec:
      containers:
        - name: scout
          image: ghcr.io/stefanprodan/podinfo:$tag
          env:
            - name: PODINFO_UI_MESSAGE
              value: \"$ui\"
          ports:
            - name: http
              containerPort: 9898
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
          resources:
            requests: {cpu: 10m, memory: 32Mi}
            limits: {memory: 64Mi}
---
apiVersion: v1
kind: Service
metadata:
  name: scout
  namespace: starfleet
  labels:
    app: scout
spec:
  selector:
    app: scout
  ports:
    - name: http
      port: 9898
      targetPort: http
YAML
git add -A
when=\$(date -u -d @\$(( \$(date +%s) - $minutes * 60 )) +%Y-%m-%dT%H:%M:%SZ)
GIT_AUTHOR_DATE=\$when GIT_COMMITTER_DATE=\$when git commit -q -m '$message'
git push -q origin main
git rev-parse HEAD" | tail -n 1
}

wait_for_sync() {
  local sha="$1" want="$2"
  kubectl -n argocd annotate application scout argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  for _ in $(seq 1 90); do
    local synced phase health
    synced="$(kubectl -n argocd get application scout -o jsonpath='{.status.operationState.syncResult.revision}' 2>/dev/null || true)"
    phase="$(kubectl -n argocd get application scout -o jsonpath='{.status.operationState.phase}' 2>/dev/null || true)"
    health="$(kubectl -n argocd get application scout -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    if [ "$synced" = "$sha" ] && [ "$phase" = "Succeeded" ] && [ "$health" = "$want" ]; then
      echo "[seed]   synced ${sha:0:7}, health $health"
      return 0
    fi
    sleep 4
  done
  echo "[seed] ERROR: ${sha:0:7} did not reach health $want" >&2
  return 1
}

GOOD="6.15.0"
BAD="6.15.0-missing"

# prometheus_has <PromQL>: true when the instant query returns a series.
prometheus_has() {
  local encoded body
  encoded="$(jq -rn --arg q "$1" '$q|@uri')"
  body="$(kubectl get --raw "/api/v1/namespaces/monitoring/services/kps-prometheus:9090/proxy/api/v1/query?query=${encoded}" 2>/dev/null || true)"
  [ "$(printf '%s' "$body" | jq -r '.data.result | length' 2>/dev/null || echo 0)" -gt 0 ] 2>/dev/null
}

# wait_for_scrape <number of syncs so far> <expected health>
wait_for_scrape() {
  local syncs="$1" want="$2"
  for _ in $(seq 1 90); do
    if prometheus_has "sum(argocd_app_sync_total{name=\"scout\",phase=\"Succeeded\"}) >= $syncs"; then
      if [ "$want" != "Degraded" ] || prometheus_has "argocd_app_info{name=\"scout\",health_status=\"Degraded\"}"; then
        return 0
      fi
    fi
    sleep 4
  done
  echo "[seed] ERROR: Prometheus never showed $syncs syncs (health $want)" >&2
  return 1
}

SYNCS=0
# step <message> <minutes before the push> <image tag> <ui message> <replicas> <expected health>
step() {
  echo "[seed] $1"
  local sha deadline=300
  [ "$3" = "$BAD" ] && deadline=30
  sha="$(push_commit "$1" "$2" "$3" "$4" "$5" "$deadline")"
  wait_for_sync "$sha" "$6"
  SYNCS=$((SYNCS + 1))
  # Let Prometheus scrape the new counter (and the Degraded health) before the next change.
  wait_for_scrape "$SYNCS" "$6"
}

step "Start scout 6.15.0"                      45 "$GOOD" "Welcome aboard" 1 Healthy
step "Change the welcome message"              30 "$GOOD" "Welcome to the fleet" 1 Healthy
step "Try a new image build"                   12 "$BAD"  "Welcome to the fleet" 1 Degraded
step "Revert the new image build"               4 "$GOOD" "Welcome to the fleet" 1 Healthy
step "Run two replicas"                        25 "$GOOD" "Welcome to the fleet" 2 Healthy
step "Change the welcome message again"        10 "$GOOD" "Welcome home" 2 Healthy
step "Try another image build"                  8 "$BAD"  "Welcome home" 2 Degraded
step "Revert the other image build"             3 "$GOOD" "Welcome home" 2 Healthy
step "Change the welcome message once more"    20 "$GOOD" "Welcome back" 2 Healthy
step "Run three replicas"                       6 "$GOOD" "Welcome back" 3 Healthy

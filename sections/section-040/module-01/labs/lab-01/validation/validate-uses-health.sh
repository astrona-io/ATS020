#!/usr/bin/env bash
# Grader: the failed deployment count comes from the health of the
# Application, not from a number typed into the rule. The expression must read
# argocd_app_info with health_status="Degraded". It must not use vector() (a
# typed-in number) and it must not rely on the sync phases Failed or Error,
# which Argo CD never records for a bad image tag.
set -uo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

EXPR="$(kubectl -n monitoring get prometheusrule dora-scout -o json 2>/dev/null \
  | jq -r '.spec.groups[].rules[] | select(.record == "dora:failed_deployments:count6h") | .expr' | tr -d ' ')"
[ -n "$EXPR" ] || fail "the rule dora:failed_deployments:count6h is missing"

case "$EXPR" in *argocd_app_info*) ;; *) fail "the failed deployment count does not read argocd_app_info";; esac
case "$EXPR" in *health_status=\"Degraded\"*|*health_status=~\"*Degraded*\"*) ;; *) fail "the failed deployment count does not look at health_status=\"Degraded\"";; esac
case "$EXPR" in *vector\(*) fail "the failed deployment count uses vector(); a typed-in number does not measure anything";; esac
case "$EXPR" in *Failed*|*Error*) fail "the failed deployment count still mentions the sync phases Failed or Error";; esac

echo "PASS: the failed deployment count reads the Degraded health of the Application"

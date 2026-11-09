#!/usr/bin/env bash
set -euo pipefail
kubectl -n argocd patch application scout --type=merge -p '{"spec":{"source":{"path":"scout"}}}'
kubectl -n argocd annotate application scout argocd.argoproj.io/refresh=hard --overwrite

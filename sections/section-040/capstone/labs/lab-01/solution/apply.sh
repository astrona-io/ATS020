#!/usr/bin/env bash
# Applies the reference solution. Run by `astrona test` only.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE=""
for candidate in "$SCRIPT_DIR/solution.yaml" "./solution/solution.yaml" "./solution.yaml"; do
  [ -f "$candidate" ] && { FILE="$candidate"; break; }
done
[ -n "$FILE" ] || { echo "[solution] ERROR: solution.yaml not found" >&2; exit 1; }
kubectl apply -f "$FILE"
kubectl -n starfleet set resources deployment/beacon --requests=cpu=10m,memory=64Mi --limits=memory=128Mi
kubectl -n starfleet rollout status deployment/beacon --timeout=180s
echo "[solution] Rules applied and beacon right-sized."

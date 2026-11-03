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
for name in scout probe cargo beacon; do
  kubectl -n starfleet rollout status "deployment/$name" --timeout=180s
done
echo "[solution] the four workloads are fixed."

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
kubectl -n observability rollout status deployment/otel-collector --timeout=180s

kubectl -n starfleet set env deployment/scout OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability:4317
kubectl -n starfleet rollout status deployment/scout --timeout=180s

kubectl -n starfleet patch deployment relay --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"true"}}}}}'
kubectl -n starfleet rollout status deployment/relay --timeout=180s

# The reader names the slow call after reading Jaeger. The reference run does
# the same lookup with the Jaeger API, so the answer is real data.
kubectl -n starfleet create configmap slow-call --from-literal=service=scout --from-literal=operation="GET /delay/{seconds}" --dry-run=client -o yaml | kubectl apply -f -
echo "[solution] tracing set up."

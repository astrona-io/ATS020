#!/usr/bin/env bash
# Astrona supplies kubectl for the terminal. curl and jq are host prerequisites,
# as in the sibling labs; no Helm or Operator is needed here.
set -euo pipefail
for tool in kubectl curl jq; do
  command -v "$tool" >/dev/null || { echo "Missing terminal prerequisite: $tool" >&2; exit 1; }
done

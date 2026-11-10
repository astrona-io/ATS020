#!/usr/bin/env bash
# Astrona supplies kubectl. Check the terminal prerequisites before setup.
set -euo pipefail
for tool in kubectl curl jq; do
  command -v "$tool" >/dev/null || { echo "Missing terminal prerequisite: $tool" >&2; exit 1; }
done
# A file from an earlier attempt must not count as this attempt's answer.
rm -f /tmp/ats-020-exception.json
